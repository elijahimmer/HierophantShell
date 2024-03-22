pub fn shellPrompt(last_status: ?u32, out: Out) !void {
    try out.config.setColor(out.file, Color.reset);
    try out.config.setColor(out.file, Color.cyan);
    try out.config.setColor(out.file, Color.bold);

    if (last_status) |ls| {
        try out.w.print("hsh {}$ ", .{ls});
    } else {
        try out.w.print("hsh$ ", .{});
    }

    try out.config.setColor(out.file, Color.reset);
}

///
const Out = @import("utils.zig").Out;

/// Std lib includes
const std = @import("std");

const File = std.fs.File;
const Color = std.io.tty.Color;
