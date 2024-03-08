pub fn main() !void {
    try os.sigaction(os.SIG.INT, &os.Sigaction{
        .handler = .{
            .handler = sigHandle,
        },
        .mask = .{0} ** 32,
        .flags = 0,
    }, null);

    const stdout_file = io.getStdOut();
    const stdout = stdout_file.writer();
    // Everything I print is direct, no need for buffer.

    try term.tty_init(stdout_file);
    try term.set_raw(stdout_file);

    const stdin = io.getStdIn().reader();

    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpalloc.deinit();

    const allocator = gpalloc.allocator();

    var history_array = ArrayList([]const u8).init(allocator);
    defer history_array.deinit();

    tty_config = tty.detectConfig(stdout_file);

    while (true) main: {
        try shellPrompt(stdout, stdout_file);

        var buf = ArrayList(u8).init(allocator);
        defer buf.deinit();

        var escape = false;
        var escape_code = false;
        var history_idx: u16 = 0;
        while (true) {
            const i = stdin.readByte() catch |err| switch (err) {
                error.EndOfStream => break :main,
                else => {
                    try stdout.print("Failed to read from stdin: {s}\n", .{@errorName(err)});
                    continue;
                },
            };

            try stdout.print(" {} ", .{i});

            if (escape) {
                if (escape_code) {
                    switch (i) {
                        'A' => { //up
                            history_idx += 1;
                        },
                        'B' => { // down
                            history_idx -= 1;
                        },
                    }
                    continue;
                }
                escape = i == '[';
                continue;
            }

            switch (i) {
                3 => break :main,
                27 => break,
                '\n' => break,
                else => try buf.append(i),
            }
        }

        try term.set_start(stdout_file);

        const command = mem.trim(u8, buf.items, &ascii.whitespace);

        if (ascii.eqlIgnoreCase(command, "exit")) {
            try stdout.writeAll("exiting...\n");

            exit(.Success);
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

    try term.set_start(stdout_file);

    process.cleanExit();
}

var last_status: ?u32 = null;
var tty_config: ?tty.Config = null;

pub fn shellPrompt(stdout: fs.File.Writer, stdout_file: fs.File) !void {
    if (tty_config) |conf| {
        try conf.setColor(stdout_file, Color.reset);
        try conf.setColor(stdout_file, Color.cyan);
        try conf.setColor(stdout_file, Color.bold);
    }

    if (last_status) |ls| {
        try stdout.print("hsh {}$ ", .{ls});
    } else {
        try stdout.writeAll("hsh$ ");
    }

    if (tty_config) |conf| {
        try conf.setColor(stdout_file, Color.reset);
    }

    try term.set_raw(stdout_file);
}

/// Tokenize a string into the command's argv
/// TODO: Implement it to follow quotes and other marks like pipes.
pub fn tokenize(allocator: Allocator, input: []const u8) Allocator.Error!ArrayList([]const u8) {
    var itr = mem.tokenize(u8, input, &ascii.whitespace);
    var arr = try ArrayList([]const u8).initCapacity(allocator, 16);

    while (itr.next()) |val| {
        try arr.append(val);
    }

    return arr;
}

const RunCommandError = error{
    NoSuchCommand,
} || os.ForkError || process.ExecvError;

/// Run a command given the argv
/// TODO: Implement piping for input and output.
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

        exit(.Failure);
    }

    current_process = pid;

    const res = os.waitpid(pid, 0);
    current_process = null;
    return res.status;
}

/// The current running process, kill this instead of the shell on ^C
var current_process: ?os.pid_t = null;

/// Catch a signal and kill the child process if one exists
fn sigHandle(sig: c_int) callconv(.C) void {
    const stdout = io.getStdOut().writer();

    stdout.print("\nCaught SIGINT: {}\n", .{sig}) catch {};

    if (current_process) |pid| {
        current_process = null;
        os.kill(pid, os.SIG.INT) catch {};
    } else {
        exit(.Success);
    }
}

const ExitCode = enum {
    Success,
    Failure,
};

fn exit(code: ExitCode) void {
    term.set_start(io.getStdOut()) catch {};

    switch (code) {
        .Success => process.cleanExit(),
        .Failure => os.exit(1),
    }

    // for debug build so it actually exits...
    os.exit(0);
}

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

const term = @import("term.zig");

const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const os = std.os;
const process = std.process;
const io = std.io;
const tty = io.tty;
const fs = std.fs;

const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const LinkedList = std.SinglyLinkedList;
const ChildProcess = std.ChildProcess;
const Color = io.tty.Color;
