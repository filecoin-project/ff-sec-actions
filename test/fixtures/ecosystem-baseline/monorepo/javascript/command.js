const child_process = require("child_process");
const command = process.env.UNTRUSTED_COMMAND;
// ruleid: filecoin.javascript.shell-command-construction
child_process.exec(command);
