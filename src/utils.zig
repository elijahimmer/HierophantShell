/// ./term.zig to reset the terminal state
const term = @import("./term.zig");

/// std library package
const std = @import("std");
const os = std.os;
const ttyConfig = std.io.tty.Config;

const File = std.fs.File;
