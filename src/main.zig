pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const stdin = std.io.getStdIn().reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    const alloc = gpa.allocator();

    try stdout.print("{s}", .{help_message});
    
    try bw.flush();

    while (true) {
        try stdout.print("hsh$ ", .{});
        try bw.flush();
        const buf = try stdin.readUntilDelimiterOrEofAlloc(alloc, '\n', 4098);
        try stdout.print(": {any} \n", .{buf});
        try bw.flush();
    }

    process.cleanExit();
}

const help_message =
    \\HSH Help Message
    \\usage:
    \\    --help
    \\        Display this message
    \\    --cmd <command> [arg1] [arg2] ...
    \\        run a shell command with arg.
    \\
;

const std = @import("std");
const process = std.process;
