pub const RunError = error{
    NoSuchCommand,
} || os.ForkError || process.ExecvError;

/// Run a command given the argv
/// TODO: Implement piping for input and output.
/// TODO: a lot more honestly
pub fn run(allocator: Allocator, argv: []const []const u8) RunError!u32 {
    if (argv.len < 1) {
        return RunError.NoSuchCommand;
    }

    const pid = try os.fork();

    if (pid == 0) { // child proccess
        var err = process.execv(allocator, argv);

        std.debug.print("{s}: {s}\n", .{ argv[0], switch (err) {
            error.FileNotFound => "command not found",
            else => @errorName(err),
        } });

        os.exit(1);
    }

    current_process = pid;

    const res = os.waitpid(pid, 0);
    current_process = null;
    return res.status;
}

/// Tokenize a string into the command's argv
/// TODO: Implement it to follow quotes and other marks like pipes.
/// TODO: Change to parse not just one command, but many
pub fn tokenize(allocator: Allocator, input: []const u8) Allocator.Error!ArrayList([]const u8) {
    var itr = mem.tokenize(u8, input, &whitespace);
    var arr = try ArrayList([]const u8).initCapacity(allocator, 16);

    while (itr.next()) |val| {
        try arr.append(val);
    }

    return arr;
}

/// The current running process, kill this instead of the shell on ^C
pub var current_process: ?os.pid_t = null;

/// std library package
const std = @import("std");
const mem = std.mem;
const os = std.os;
const process = std.process;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const whitespace = std.ascii.whitespace;
