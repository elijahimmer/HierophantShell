/// The current running process, kill this instead of the shell on ^C
pub var current_process: ?os.pid_t = null;

pub fn registerSignals() void {
    try os.sigaction(os.SIG.INT, &os.Sigaction{
        .handler = .{
            .handler = sigIntHandle,
        },
        .mask = .{0} ** 32,
        .flags = 0,
    }, null);
}

/// Catch a signal and kill the child process if one exists
pub fn sigIntHandle(sig: c_int) callconv(.C) void {
    _ = sig;

    if (current_process) |pid| {
        current_process = null;
        os.kill(pid, os.SIG.INT) catch {};
    } else {
        if (term.last_start) |ls| {
            term.set(std.io.getStdOut(), &ls);
        }
        os.exit(0);
    }
}

pub const Out = struct {
    file: File,
    w: File.Writer,
    config: ttyConfig,
};

/// ./term.zig to reset the terminal state
const term = @import("./term.zig");

/// std library package
const std = @import("std");
const os = std.os;
const ttyConfig = std.io.tty.Config;

const File = std.fs.File;
