
fn sigHandler() void {
    os.Sigaction
}


fn sigAction() void {
}

pub fn main() !void {

    os.sigaction(os.SIG.QUIT, .{handler = sigHandler,
    sigaction = sigAction,}, sigQuit2);

    const stdout_file = io.getStdOut();
    const stdout = stdout_file.writer();
    // Everything I print is direct, no need for buffer.

    const stdin = io.getStdIn().reader();

    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpalloc.deinit();

    const allocator = gpalloc.allocator();

    var history_array = ArrayList([]const u8).init(allocator);
    defer history_array.deinit();

    var last_status: ?u32 = null;

    var config = tty.detectConfig(stdout_file);
    try config.setColor(stdout_file, Color.reset);

    while (true) {
        try config.setColor(stdout_file, Color.cyan);
        try config.setColor(stdout_file, Color.bold);

        if (last_status) |ls| {
            try stdout.print("hsh {}$ ", .{ls});
        } else {
            try stdout.print("hsh$ ", .{});
        }


        try config.setColor(stdout_file, Color.reset);

        const buf = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', MAX_LINE_BUFFER) orelse break;
        defer allocator.free(buf);

        const command = mem.trim(u8, buf, &ascii.whitespace);

        if (ascii.eqlIgnoreCase(command, "exit")) {
            try stdout.writeAll("exiting...\n");
            break;
        }

        if (ascii.eqlIgnoreCase(command, "help")) {
            try stdout.print("{s}\n", .{HELP_MESSAGE});
            continue;
        }

        var arg_arr = try tokenize(allocator, command);
        defer arg_arr.deinit();

        last_status = run_command(allocator, arg_arr.items) catch |err| rcmd: {
            switch (err) {
                RunCommandError.NoSuchCommand => {},
                else => try stdout.print("failed to run command: {s}\n", .{@errorName(err)}),

            }
            break :rcmd null;
        };
    }

    process.cleanExit();
}

//// Tokenize a string into the command's argv
//// TODO: Implement it to follow quotes and other marks like pipes.
pub fn tokenize(allocator: Allocator, input: []const u8) Allocator.Error!ArrayList([]const u8) {
    var itr = mem.tokenize(u8, input, &ascii.whitespace);
    var arr = try ArrayList([]const u8).initCapacity(allocator, 16);

    while (itr.next()) |val| {
        try arr.append(val);
    }

    return arr;
}

const RunCommandError = error {
    NoSuchCommand,
} || os.ForkError || process.ExecvError;

//// Run a command given the argv
//// TODO: Implement piping for input and output.
pub fn run_command(allocator: Allocator, argv: []const []const u8) RunCommandError!u32 {
    if (argv.len < 1) {
        return RunCommandError.NoSuchCommand;
    }

    const pid = try os.fork();

    if (pid == 0) {
        var err = process.execv(allocator, argv);

        std.debug.print("{s}: {s}\n", .{ argv[0], switch (err) {
            error.FileNotFound => "command not found",
            else => @errorName(err),
        } });

        os.exit(1);
    }

    current_process = pid;

    const res = os.waitpid(pid, 0);
    return res.status;
}

//// The current running process, kill this instead of the shell on ^C
var current_process: ?os.pid_t = null;

const CMD_HELP_MESSAGE =
    \\
    \\hsh Help Message
    \\usage:
    \\    --help
    \\        Display this message
    \\    --cmd <command> [arg1] [arg2] ...
    \\        run a shell command with arg.
    \\
    \\
;

const HELP_MESSAGE =
    \\
    \\help: prints this message
    \\exit: exits the shell
    \\
;

//// The max length of the buffer allocated for reading from the stdin
////    A far more than reasonable max buffer size
const MAX_LINE_BUFFER = 1 << 16;

const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const os = std.os;
const process = std.process;
const io = std.io;
const tty = io.tty;

const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const ChildProcess = std.ChildProcess;
const Color = io.tty.Color;
const assert = std.debug.assert;
