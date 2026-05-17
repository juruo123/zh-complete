use std::fs;
use std::os::unix::fs::symlink;
use std::path::Path;
use std::process::Command;

fn binary() -> Command {
    Command::new(env!("CARGO_BIN_EXE_pinyin-path"))
}

fn run(args: &[&str], cwd: &Path) -> std::process::Output {
    binary()
        .args(args)
        .current_dir(cwd)
        .output()
        .expect("failed to run pinyin-path")
}

#[test]
fn help_exits_successfully() {
    let output = binary().arg("--help").output().unwrap();
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("pinyin-path"));
}

#[test]
fn no_match_exits_with_code_1() {
    let tmp = tempfile::tempdir().unwrap();
    let output = run(&["--dirs", "nonexistent"], tmp.path());
    assert_eq!(output.status.code(), Some(1));
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("no match"), "stderr: {stderr}");
}

#[test]
fn ambiguous_match_exits_with_code_2() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("工作")).unwrap();
    fs::create_dir(tmp.path().join("工作报告")).unwrap();

    let output = run(&["--dirs", "gong"], tmp.path());
    assert_eq!(output.status.code(), Some(2));
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("multiple matches"), "stderr: {stderr}");
    assert!(stderr.contains("工作"), "stderr: {stderr}");
}

#[test]
fn single_match_prints_path() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("工作")).unwrap();
    fs::write(tmp.path().join("其他.txt"), "").unwrap();

    let output = run(&["--dirs", "gongzuo"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.trim().ends_with("工作"), "stdout: {stdout}");
}

#[test]
fn dirs_flag_excludes_files() {
    let tmp = tempfile::tempdir().unwrap();
    fs::write(tmp.path().join("工作.txt"), "").unwrap();

    let output = run(&["--dirs", "gongzuo"], tmp.path());
    assert_eq!(output.status.code(), Some(1));
}

#[test]
fn files_flag_excludes_directories() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("工作")).unwrap();
    fs::write(tmp.path().join("工作报告.txt"), "").unwrap();

    let output = run(&["--files", "gzbg"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("工作报告.txt"), "stdout: {stdout}");
}

#[test]
fn list_flag_shows_multiple_candidates() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("工作")).unwrap();
    fs::create_dir(tmp.path().join("工作报告")).unwrap();

    let output = run(&["--dirs", "--list", "gong"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    let lines: Vec<_> = stdout.lines().collect();
    assert_eq!(lines.len(), 2, "expected 2 lines, got: {lines:?}");
}

#[test]
fn json_flag_outputs_valid_json() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("工作")).unwrap();

    let output = run(&["--dirs", "--json", "gongzuo"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    let parsed: serde_json::Value =
        serde_json::from_str(stdout.trim()).expect("valid JSON");
    assert_eq!(parsed["file_name"], "工作");
    assert_eq!(parsed["is_dir"], true);
    assert_eq!(parsed["full_pinyin"], "gongzuo");
    assert_eq!(parsed["initials"], "gz");
}

#[test]
fn json_list_outputs_json_array() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("工作")).unwrap();
    fs::create_dir(tmp.path().join("工作报告")).unwrap();

    let output = run(&["--dirs", "--list", "--json", "gong"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    let parsed: Vec<serde_json::Value> =
        serde_json::from_str(stdout.trim()).expect("JSON array");
    assert_eq!(parsed.len(), 2);
}

#[test]
fn json_no_match_outputs_null() {
    let tmp = tempfile::tempdir().unwrap();
    let output = run(&["--dirs", "--json", "xyz"], tmp.path());
    assert_eq!(output.status.code(), Some(1));
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.trim() == "null", "stdout: {stdout}");
}

#[test]
fn json_ambiguous_outputs_array() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("工作")).unwrap();
    fs::create_dir(tmp.path().join("工作报告")).unwrap();

    let output = run(&["--dirs", "--json", "gong"], tmp.path());
    assert_eq!(output.status.code(), Some(2));
    let stdout = String::from_utf8_lossy(&output.stdout);
    let parsed: Vec<serde_json::Value> =
        serde_json::from_str(stdout.trim()).expect("JSON array for ambiguous");
    assert_eq!(parsed.len(), 2);
}

#[test]
fn cwd_flag_scans_given_directory() {
    let tmp = tempfile::tempdir().unwrap();
    let sub = tmp.path().join("subdir");
    fs::create_dir(&sub).unwrap();
    fs::create_dir(sub.join("工作")).unwrap();

    // Run from tmp but scanning subdir
    let output = run(&["--dirs", "--cwd", sub.to_str().unwrap(), "gongzuo"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("工作"), "stdout: {stdout}");
}

#[test]
fn handles_spaces_in_filenames() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("工作 报告")).unwrap();

    let output = run(&["--dirs", "gongzuobaogao"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("工作 报告"), "stdout: {stdout}");
}

#[test]
fn handles_mixed_chinese_and_ascii() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("Rust学习笔记")).unwrap();

    let output = run(&["--dirs", "rustxx"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("Rust学习笔记"), "stdout: {stdout}");
}

#[test]
fn matches_by_initials() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("工作报告")).unwrap();

    let output = run(&["--dirs", "gzbg"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("工作报告"), "stdout: {stdout}");
}

#[test]
fn handles_symlink_to_directory() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("工作")).unwrap();
    symlink(tmp.path().join("工作"), tmp.path().join("工作链接")).unwrap();

    let output = run(&["--dirs", "gongzuo"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    // Symlink is followed, so it should match either name
    assert!(
        stdout.contains("工作链接") || stdout.contains("工作"),
        "stdout: {stdout}"
    );
}

#[test]
fn pure_ascii_names_are_excluded() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("compiler")).unwrap();
    fs::create_dir(tmp.path().join("工作")).unwrap();

    // "com" should only match 工作 (via gongzuo prefix), not compiler.
    // In fact, there should be no match because "com" does not start with "gong".
    let output = run(&["--dirs", "com"], tmp.path());
    // compiler is pure ASCII, so only 工作 would be considered — but
    // 工作 starts with "gongzuo", not "com", so no match at all.
    assert_eq!(output.status.code(), Some(1));
}

#[test]
fn chinese_names_work_alongside_ascii_names() {
    let tmp = tempfile::tempdir().unwrap();
    fs::create_dir(tmp.path().join("compiler")).unwrap();
    fs::create_dir(tmp.path().join("工作")).unwrap();

    // "gong" matches 工作 via full pinyin prefix, compiler excluded.
    let output = run(&["--dirs", "gong"], tmp.path());
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("工作"), "stdout: {stdout}");
    assert!(!stdout.contains("compiler"), "stdout: {stdout}");
}
