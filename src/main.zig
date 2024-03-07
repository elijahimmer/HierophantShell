pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    // Everything I print is direct, no need for buffer.

    const stdin = std.io.getStdIn().reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    try stdout.print("{s}", .{HELP_MESSAGE});

    while (true) {
        try stdout.print("hsh$ ", .{});

        const buf = (try stdin.readUntilDelimiterOrEofAlloc(alloc, '\n', MAX_LINE_BUFFER)).?;
        defer alloc.free(buf);

        if (ascii.eqlIgnoreCase(buf, "exit")) {
            break;
        }
        if (ascii.eqlIgnoreCase(buf, "help")) {
            try stdout.print("{s}", .{HELP_MESSAGE});
            continue;
        }

        _ =  try tokenize(alloc, buf);
    }

    std.process.cleanExit();
}

pub fn tokenize(allocator: Allocator, input: []const u8) !ArrayList([] u8) {
    const trimed = mem.trim(u8, input, &ascii.whitespace);

    var itr = mem.tokenize(u8, trimed, &ascii.whitespace);
    var arr = ArrayList([]const u8).init(allocator);

    while (itr.next()) |val| {
        try arr.append(val);
        std.debug.print("{s}\n", .{val});
    }


    return arr;
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
    \\
;

//// The max length of the buffer allocated for reading from the stdin
//// A far more than reasonable max buffer size
const MAX_LINE_BUFFER = 1 << 16;

const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;

const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
