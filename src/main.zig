pub fn main() !void {
    resetOnSigInt();

    const stdout_file = io.getStdOut();
    var stdout_buf = io.bufferedWriter(stdout_file.writer());
    const stdout = stdout_buf.writer();

    var o = .{
        .file = stdout_file,
        .buf = &stdout_buf,
        .out = stdout,
        .config = std.io.tty.detectConfig(stdout_file),
    };

    // General allocator
    //const allocator = std.heap.c_allocator;

    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpalloc.deinit();

    const allocator = gpalloc.allocator();

    // History Arena
    var history_arena = ArenaAllocator.init(allocator);
    defer history_arena.deinit();

    const history_alloc = history_arena.allocator();

    var history = ArrayList([]const u8).init(history_alloc);

    // Clone History Arena
    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();

    while (true) {
        // Ignore whether or not the retain worked.
        _ = arena.reset(.retain_capacity);

        var history_clone = try clone_history(arena.allocator(), &history);

        const command_raw = readline(&history_clone, &o) catch |err| {
            switch (err) {
                error.SIGINT => continue,
                else => return err,
            }
        };

        const command_buf = try history_alloc.alloc(u8, command_raw.items.len);

        @memcpy(command_buf, command_raw.items);

        const command = mem.trim(u8, command_buf, &whitespace);

        if (command.len == 0) continue;

        try history.append(command);

        //try stdout.print("\t{}: '{s}'\n", .{ command.len, command });

        if (ascii.eqlIgnoreCase(command, "exit")) {
            return;
        }

        if (ascii.eqlIgnoreCase(command, "help")) {
            try stdout.print("{s}\n", .{strings.HELP_MESSAGE});
        }

        var arg_arr = try run.tokenize(history_alloc, command);

        const last_status = run.run(history_alloc, arg_arr.items) catch |err| rcmd: {
            switch (err) {
                error.NoSuchCommand => {},
                else => try stdout.print("\nfailed to run command: {s}\n", .{@errorName(err)}),
            }
            break :rcmd null;
        };

        _ = last_status;
    }
}

/// Clones the history ArrayList into a mutable double ArrayList
fn clone_history(alloc: Allocator, history: *ArrayList([]const u8)) Allocator.Error!ArrayList(ArrayList(u8)) {
    var history_clone = try ArrayList(ArrayList(u8)).initCapacity(alloc, history.capacity + 1);

    for (history.items) |command| {
        var line = try ArrayList(u8).initCapacity(alloc, command.len);

        line.appendSliceAssumeCapacity(command);

        history_clone.appendAssumeCapacity(line);
    }

    history_clone.appendAssumeCapacity(ArrayList(u8).init(alloc));

    return history_clone;
}

/// Overrides the default panic to reset terminal mode
pub fn panic(message: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    term.emergencyResetTerm();

    std.builtin.default_panic(message, error_return_trace, ret_addr);
}

/// Sets a sigaction on SIGINT to fix the terminal's mode
pub fn resetOnSigInt() void {
    os.sigaction(os.SIG.INT, &os.Sigaction{
        .handler = .{
            .handler = sigIntHandle,
        },
        .mask = .{0} ** 32,
        .flags = 0,
    }, null) catch {};
}

/// Catch a signal and kill the child process if one exists
fn sigIntHandle(sig: c_int) callconv(.C) void {
    _ = sig;

    if (run.current_process) |pid| {
        os.kill(pid, os.SIG.INT) catch |err| {
            std.debug.print("failed to kill {}: {s}", .{ pid, @errorName(err) });
        };
        run.current_process = null;
        std.debug.print("\n", .{});
    } else {
        term.emergencyResetTerm();
        os.exit(0);
    }
}

/// ./strings.zig
const strings = @import("strings.zig");

/// ./readline.zig
const readline = @import("readline.zig").readline;

/// ./term.zig
const term = @import("term.zig");

/// ./run.zig
const run = @import("run.zig");

/// std library package
const std = @import("std");
const mem = std.mem;
const os = std.os;
const io = std.io;
const ascii = std.ascii;

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;

const whitespace = std.ascii.whitespace;
