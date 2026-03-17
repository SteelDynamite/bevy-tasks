use colored::*;

pub fn success(message: &str) {
    println!("{} {}", "✓".green(), message);
}

pub fn error(message: &str) {
    eprintln!("{} {}", "✗".red(), message);
}

pub fn warning(message: &str) {
    println!("{} {}", "⚠".yellow(), message);
}

pub fn info(message: &str) {
    println!("{} {}", "ℹ".blue(), message);
}
