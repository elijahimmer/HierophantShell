pub fn main() !void {
    const stdout_file = io.getStdOut();
    const stdout = stdout_file.writer();
    // Everything I print is direct, no need for buffer.

    const stdin = io.getStdIn().reader();

    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpalloc.deinit();

    const allocator = gpalloc.allocator();

    var history_array = ArrayList([]const u8).init(allocator);
    defer history_array.deinit();

    var last_status: u32 = 0;

    var config = tty.detectConfig(stdout_file);
    while (true) {
        try config.setColor(stdout_file, Color.cyan);
        try config.setColor(stdout_file, Color.bold);

        try stdout.print("hsh {}$ ", .{last_status});

        try config.setColor(stdout_file, Color.reset);

        const buf = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', MAX_LINE_BUFFER) orelse break;
        defer allocator.free(buf);

        const command = mem.trim(u8, buf, &ascii.whitespace);

        if (ascii.eqlIgnoreCase(command, "exit")) {
            try stdout.print("exiting...\n", .{});
            break;
        }

        if (ascii.eqlIgnoreCase(command, "help")) {
            try stdout.print("{s}\n", .{HELP_MESSAGE});
            continue;
        }

        var arg_arr = try tokenize(allocator, command);
        defer arg_arr.deinit();

        last_status = run_command(allocator, arg_arr.items) catch |err| rcmd: {
            try stdout.print("failed to run command: {}\n", .{err});
            break :rcmd 0;
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

//// Run a command given the argv
//// TODO: Implement piping for input and output.
pub fn run_command(allocator: Allocator, argv: []const []const u8) anyerror!u32 {
    assert(argv.len > 0);
    //var child = ChildProcess.init(argv, allocator);

    //try child.spawn();

    //_ = try child.wait();

    _ = &allocator;
    _ = &argv;

    const pid = try os.fork();

    if (pid == 0) {
        var err = process.execv(allocator, argv);

        const stdout = io.getStdOut().writer();

        try stdout.print("{s}: {s}\n", .{ argv[0], switch (err) {
            error.FileNotFound => "command not found",
            else => @errorName(err),
        } });

        os.exit(1);
    }

    const res = os.waitpid(pid, 0);
    return res.status;
}

//var current_process: ?pid_t = null;

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
