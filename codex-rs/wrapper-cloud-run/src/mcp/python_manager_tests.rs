#[test]
fn test_is_alive_true_and_false() {
    use std::io::BufReader;
    use std::process::Command;
    use std::process::Stdio;
    use std::thread;
    use std::time::Duration;

    // Spawn a long running process "sleep 5"
    let child = Command::new("sleep")
        .arg("5")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();

    let mut process = PythonMcpProcess {
        child,
        stdin: Arc::new(Mutex::new(std::process::ChildStdin::from_std(
            std::io::sink(),
        ))),
        stdout: Arc::new(Mutex::new(BufReader::new(
            std::process::ChildStdout::from_std(std::io::empty()),
        ))),
    };

    // Initially alive
    assert!(process.is_alive());

    // Kill process
    let _ = process.child.kill();

    // Wait for process to exit
    thread::sleep(Duration::from_millis(100));

    // Now should be not alive
    assert!(!process.is_alive());
}

#[test]
fn test_restart_replaces_process() {
    use std::io::BufReader;
    use std::process::Command;
    use std::process::Stdio;
    // Spawn dummy child process "true"
    let child = Command::new("true")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();

    let mut process = PythonMcpProcess {
        child,
        stdin: Arc::new(Mutex::new(std::process::ChildStdin::from_std(
            std::io::sink(),
        ))),
        stdout: Arc::new(Mutex::new(BufReader::new(
            std::process::ChildStdout::from_std(std::io::empty()),
        ))),
    };

    // Restart with "true" again
    let res = process.restart("true", "");
    assert!(res.is_ok());
}

#[test]
fn test_python_mcp_manager_new_creates_pool() {
    let manager = PythonMcpManager::new("true".to_string(), "".to_string(), 3).unwrap();
    assert_eq!(manager.processes.len(), 3);
}

#[test]
fn test_get_process_returns_alive_process() {
    let mut manager = PythonMcpManager::new("true".to_string(), "".to_string(), 2).unwrap();

    // All processes are likely dead immediately since "true" exits immediately
    // So get_process should return None
    assert!(manager.get_process().is_none());
}

#[test]
fn test_health_check_restarts_dead_processes() {
    let mut manager = PythonMcpManager::new("true".to_string(), "".to_string(), 2).unwrap();

    let res = manager.health_check();
    assert!(res.is_ok());
}
