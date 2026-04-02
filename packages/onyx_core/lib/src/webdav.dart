import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'error.dart';

/// Information about a file on the remote WebDAV server.
class RemoteFileInfo {
  final String path;
  final bool isDir;
  final int contentLength;
  final String? lastModified;

  RemoteFileInfo({
    required this.path,
    required this.isDir,
    this.contentLength = 0,
    this.lastModified,
  });
}

/// Abstract credential store for WebDAV authentication.
abstract class CredentialStore {
  (String, String)? loadCredentials(String domain);
  void storeCredentials(String domain, String username, String password);
  void deleteCredentials(String domain);
}

/// Credential store that reads from environment variables.
class EnvVarCredentialStore implements CredentialStore {
  @override
  (String, String)? loadCredentials(String domain) {
    var user = Platform.environment['ONYX_WEBDAV_USER'];
    var pass = Platform.environment['ONYX_WEBDAV_PASS'];
    if (user != null && pass != null) return (user, pass);
    return null;
  }

  @override
  void storeCredentials(String domain, String username, String password) {
    throw CredentialError('EnvVarCredentialStore does not support storing credentials');
  }

  @override
  void deleteCredentials(String domain) {
    throw CredentialError('EnvVarCredentialStore does not support deleting credentials');
  }
}

/// Percent-encode a single path segment (not the whole path).
String _percentEncode(String segment) {
  var buf = StringBuffer();
  for (var byte in utf8.encode(segment)) {
    if ((byte >= 0x41 && byte <= 0x5a) || // A-Z
        (byte >= 0x61 && byte <= 0x7a) || // a-z
        (byte >= 0x30 && byte <= 0x39) || // 0-9
        byte == 0x2d || byte == 0x5f || byte == 0x2e || byte == 0x7e) {
      buf.writeCharCode(byte);
    } else {
      buf.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return buf.toString();
}

/// Percent-decode a string.
String _percentDecode(String s) {
  var bytes = <int>[];
  var i = 0;
  var codeUnits = s.codeUnits;
  while (i < codeUnits.length) {
    if (codeUnits[i] == 0x25 && i + 2 < codeUnits.length) { // '%'
      var hex = s.substring(i + 1, i + 3);
      var val = int.tryParse(hex, radix: 16);
      if (val != null) {
        bytes.add(val);
        i += 3;
        continue;
      }
    }
    bytes.add(codeUnits[i]);
    i++;
  }
  return utf8.decode(bytes, allowMalformed: true);
}

const _propfindBody = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:resourcetype/>
    <D:getcontentlength/>
    <D:getlastmodified/>
  </D:prop>
</D:propfind>''';

/// WebDAV client with HTTP basic auth.
class WebDavClient {
  final http.Client _client;
  final String _baseUrl;
  final String _username;
  final String _password;

  WebDavClient(String baseUrl, this._username, this._password)
      : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = http.Client();

  String _fullUrl(String path) {
    var trimmed = path.startsWith('/') ? path.substring(1) : path;
    if (trimmed.isEmpty) return _baseUrl;
    var encoded = trimmed.split('/').map(_percentEncode).join('/');
    return '$_baseUrl/$encoded';
  }

  Map<String, String> _authHeaders() {
    var credentials = base64Encode(utf8.encode('$_username:$_password'));
    return {'Authorization': 'Basic $credentials'};
  }

  /// Test connection by issuing a PROPFIND depth 0 on the root.
  Future<void> testConnection() async {
    var uri = Uri.parse(_baseUrl);
    var request = http.Request('PROPFIND', uri);
    request.headers.addAll(_authHeaders());
    request.headers['Depth'] = '0';
    request.headers['Content-Type'] = 'application/xml';
    request.body = _propfindBody;

    var streamedResponse = await _client.send(request);
    var status = streamedResponse.statusCode;
    await streamedResponse.stream.drain<void>();
    if (status == 207 || status == 200) return;
    if (status == 401 || status == 403) throw CredentialError('Authentication failed');
    throw WebDavError('Unexpected status $status');
  }

  /// List files at a given path using PROPFIND depth 1.
  Future<List<RemoteFileInfo>> listFiles(String path) async {
    var url = _fullUrl(path);
    var uri = Uri.parse(url);
    var request = http.Request('PROPFIND', uri);
    request.headers.addAll(_authHeaders());
    request.headers['Depth'] = '1';
    request.headers['Content-Type'] = 'application/xml';
    request.body = _propfindBody;

    var streamedResponse = await _client.send(request);
    var status = streamedResponse.statusCode;
    var body = await streamedResponse.stream.bytesToString();
    if (status != 207) throw WebDavError('PROPFIND failed with status $status');

    return _parsePropfindResponse(body, _baseUrl, path);
  }

  /// Download a file's contents.
  Future<List<int>> getFile(String path) async {
    var url = _fullUrl(path);
    var response = await _client.get(Uri.parse(url), headers: _authHeaders());
    if (response.statusCode == 404) throw NotFoundError('Remote file not found: $path');
    if (response.statusCode != 200) throw WebDavError('GET failed with status ${response.statusCode}');
    return response.bodyBytes;
  }

  /// Upload a file.
  Future<void> putFile(String path, List<int> content) async {
    var url = _fullUrl(path);
    var response = await _client.put(Uri.parse(url), headers: _authHeaders(), body: content);
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw WebDavError('PUT failed with status ${response.statusCode}');
    }
  }

  /// Delete a remote file.
  Future<void> deleteFile(String path) async {
    var url = _fullUrl(path);
    var response = await _client.delete(Uri.parse(url), headers: _authHeaders());
    if (response.statusCode == 404) return; // Already gone
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw WebDavError('DELETE failed with status ${response.statusCode}');
    }
  }

  /// Create a directory via MKCOL.
  Future<void> createDir(String path) async {
    var url = _fullUrl(path);
    var uri = Uri.parse(url);
    var request = http.Request('MKCOL', uri);
    request.headers.addAll(_authHeaders());

    var streamedResponse = await _client.send(request);
    var status = streamedResponse.statusCode;
    await streamedResponse.stream.drain<void>();
    if (status == 405) return; // Already exists
    if (status < 200 || status > 299) throw WebDavError('MKCOL failed with status $status');
  }

  /// Ensure a directory exists, creating it and parents as needed.
  Future<void> ensureDir(String path) async {
    var parts = path.split('/').where((s) => s.isNotEmpty).toList();
    var current = '';
    for (var part in parts) {
      current = current.isEmpty ? part : '$current/$part';
      await createDir(current);
    }
  }
}

/// Extract the local name from a potentially namespaced XML element.
String _localName(XmlElement element) {
  return element.localName;
}

/// Extract a relative path from an href, stripping the base URL prefix and the request path.
String _extractRelativePath(String href, String baseUrl, String requestPath) {
  var decoded = _percentDecode(href);
  // Strip scheme + host if present
  String path;
  var schemeIdx = decoded.indexOf('://');
  if (schemeIdx != -1) {
    var afterScheme = decoded.substring(schemeIdx + 3);
    var slashIdx = afterScheme.indexOf('/');
    path = slashIdx != -1 ? afterScheme.substring(slashIdx) : '';
  } else {
    path = decoded;
  }

  // Extract the base path from baseUrl
  String basePath;
  var baseSchemeIdx = baseUrl.indexOf('://');
  if (baseSchemeIdx != -1) {
    var afterScheme = baseUrl.substring(baseSchemeIdx + 3);
    var slashIdx = afterScheme.indexOf('/');
    basePath = slashIdx != -1 ? afterScheme.substring(slashIdx) : '';
  } else {
    basePath = '';
  }

  // Strip base path prefix
  var relative = path;
  if (basePath.isNotEmpty) {
    var bp = basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;
    if (relative.startsWith(bp)) relative = relative.substring(bp.length);
  }

  // Strip request path prefix
  var req = requestPath.replaceAll(RegExp(r'^/+|/+$'), '');
  if (req.isNotEmpty) {
    var prefixed = '/$req';
    if (relative.startsWith(prefixed)) relative = relative.substring(prefixed.length);
  }

  // Trim slashes
  relative = relative.replaceAll(RegExp(r'^/+|/+$'), '');
  return relative;
}

/// Parse a PROPFIND multistatus XML response into RemoteFileInfo entries.
List<RemoteFileInfo> _parsePropfindResponse(String xml, String baseUrl, String requestPath) {
  var document = XmlDocument.parse(xml);
  var results = <RemoteFileInfo>[];

  // Find all response elements regardless of namespace prefix
  var responses = document.findAllElements('response').toList();
  if (responses.isEmpty) {
    responses = document.findAllElements('d:response').toList();
  }
  if (responses.isEmpty) {
    responses = document.findAllElements('D:response').toList();
  }
  // Also try namespace-aware search
  if (responses.isEmpty) {
    for (var element in document.descendants.whereType<XmlElement>()) {
      if (_localName(element) == 'response') responses.add(element);
    }
  }

  for (var response in responses) {
    String? href;
    var isDir = false;
    var contentLength = 0;
    String? lastModified;

    for (var element in response.descendants.whereType<XmlElement>()) {
      var local = _localName(element);
      switch (local) {
        case 'href':
          href = element.innerText;
        case 'collection':
          isDir = true;
        case 'getcontentlength':
          contentLength = int.tryParse(element.innerText.trim()) ?? 0;
        case 'getlastmodified':
          lastModified = element.innerText;
      }
    }

    if (href != null) {
      var path = _extractRelativePath(href, baseUrl, requestPath);
      if (path.isNotEmpty) {
        results.add(RemoteFileInfo(
          path: path,
          isDir: isDir,
          contentLength: contentLength,
          lastModified: lastModified,
        ));
      }
    }
  }

  return results;
}
