import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameController = TextEditingController();
  String? _selectedPath;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) setState(() => _selectedPath = result);
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedPath == null) return;
    await context.read<AppState>().addWorkspace(name, _selectedPath!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 384),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bevy Tasks',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textDark : AppTheme.textLight)),
              const SizedBox(height: 4),
              Text('Create or open a workspace to get started.',
                style: TextStyle(fontSize: 14, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
              const SizedBox(height: 24),
              // Workspace name label + input
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Workspace name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.textDark : AppTheme.textLight)),
              ),
              TextField(
                controller: _nameController,
                style: TextStyle(fontSize: 14, color: isDark ? AppTheme.textDark : AppTheme.textLight),
                decoration: InputDecoration(
                  hintText: 'My Tasks',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                  filled: false,
                ),
              ),
              const SizedBox(height: 16),
              // Folder label + picker row
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Folder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.textDark : AppTheme.textLight)),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      style: TextStyle(fontSize: 14, color: isDark ? AppTheme.textDark : AppTheme.textLight),
                      controller: TextEditingController(text: _selectedPath ?? ''),
                      decoration: InputDecoration(
                        hintText: 'Select a folder\u2026',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                        filled: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _pickFolder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Browse', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_nameController.text.trim().isNotEmpty && _selectedPath != null) ? _create : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Create Workspace', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
