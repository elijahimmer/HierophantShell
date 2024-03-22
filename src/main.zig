pub fn main() !void {

    // Everything I print is direct, no need for buffer.

    // For non-libc allocating
    //var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    //defer _ = gpalloc.deinit();

    //const allocator = gpalloc.allocator();

    const allocator = std.heap.c_allocator;

    const stdout_file = io.getStdOut();
    const stdout = stdout_file.writer();
    const out = utils.Out{
        .file = stdout_file,
        .w = stdout,
        .config = ttyDetectConfig(stdout_file),
    };

    var history_array = ArrayList([]const u8).init(allocator);
    defer history_array.deinit();

    while (true) {
        const line = try readline(allocator, history_array, out);
        const command = mem.trim(u8, line, &whitespace);

        if (mem.eql(u8, command, "exit")) {
            break;
        }

        if (command.len > 0) {
            try history_array.insert(0, command);
        }
    }
}

/// ./readline.zig
const readline = @import("readline.zig").readline;

/// ./utils.zig
const utils = @import("utils.zig");

/// ./term.zig
const term = @import("term.zig");

/// std library package
const std = @import("std");
const io = std.io;
const mem = std.mem;
const ttyDetectConfig = io.tty.detectConfig;
const whitespace = std.ascii.whitespace;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
