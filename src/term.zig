pub fn tty_init(stdout_file: File) !void {
    var tty_tmp: termios.termios = undefined;

    switch (os.errno(termios.tcgetattr(stdout_file.handle, &tty_tmp))) {
        .SUCCESS => {},
        else => |err| {
            try stdout_file.writer().print("Failed to get tty status: {}\n", .{err});
            return;
        },
    }

    tty_start = tty_tmp;

    tty_tmp.c_lflag &= @bitCast(~(termios.ICANON | termios.VINTR));

    tty_raw = tty_tmp;
}

pub fn set_start(stdout_file: File) !void {
    if (current_mode == .Start) return;
    if (tty_start) |start| {
        switch (os.errno(termios.tcsetattr(stdout_file.handle, 0, &start))) {
            .SUCCESS => current_mode = Mode.Start,
            else => |err| try stdout_file.writer().print("Failed to set tty back from mode: {}\n", .{err}),
        }
    }
}

pub fn set_raw(stdout_file: File) !void {
    if (current_mode == .Raw) return;
    if (tty_raw) |raw| {
        switch (os.errno(termios.tcsetattr(stdout_file.handle, 0, &raw))) {
            .SUCCESS => current_mode = Mode.Raw,
            else => |err| try stdout_file.writer().print("Failed to set tty to raw mode: {}\n", .{err}),
        }
    }
}

var tty_success = false;
var tty_raw: ?termios.termios = null;
var tty_start: ?termios.termios = null;

const Mode = enum {
    Raw,
    Start,
};

var current_mode = Mode.Start;

const std = @import("std");
const os = std.os;
const File = std.fs.File;

const termios = @cImport(@cInclude("termios.h"));
