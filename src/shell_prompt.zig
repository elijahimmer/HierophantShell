pub fn shellPrompt(last_status: ?u32, o: anytype) !void {
    try o.config.setColor(o.file, Color.reset);
    try o.config.setColor(o.file, Color.cyan);
    try o.config.setColor(o.file, Color.bold);

    if (last_status) |ls| {
        try o.out.print("hsh {}$ ", .{ls});
    } else {
        try o.out.print("hsh$ ", .{});
    }

    try o.config.setColor(o.file, Color.reset);
}

///
const Out = @import("utils.zig").Out;

/// Std lib includes
const std = @import("std");

const File = std.fs.File;
const Color = std.io.tty.Color;
const detectConfig = std.io.tty.detectConfig;
