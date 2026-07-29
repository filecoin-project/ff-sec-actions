use std::process::Command;

fn unsafe_shell(command: &str) {
    // ruleid: filecoin.rust.shell-command-construction
    Command::new("sh").arg("-c").arg(command).status().unwrap();
}
