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

pub const IOTypeTag = enum {
    normal,
    pipe,
    file,
};

pub const IOType = union(IOTypeTag) {
    normal: void,
    pipe: void,
    file: []const u8,
};

pub const Command = struct {
    input: IOType,
    output: IOType,
    argv: []const []const u8,
};

/// The current running process, kill this instead of the shell on ^C
pub var current_process: ?os.pid_t = null;

const nil = @as(void, undefined);

const tokenize = @import("./tokenize").tokenize;

/// std library package
const std = @import("std");
const mem = std.mem;
const os = std.os;
const process = std.process;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const whitespace = std.ascii.whitespace;

const expect = std.testing.expect;
