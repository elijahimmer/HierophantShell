pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const stdin = std.io.getStdIn().reader();

    const alloc = std.heap.page_allocator;
    
    try bw.flush();
    
    var buf = try std.ArrayList(u8).initCapacity(alloc, 1024);

    while (true) {
        try stdin.readUntilDelimiterArrayList(&buf, '\n', 1024);

        try stdout.print(": {} \n", .{buf});
    }

    process.cleanExit();
}

const std = @import("std");
const process = std.process;
