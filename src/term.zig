pub const Config = struct {
    start: termios.termios,
    raw: termios.termios,
};

pub fn get(stdout_file: File) ?Config {
    if (!isatty(stdout_file.handle)) {
        return null;
    }

    var term_start: termios.termios = undefined;

    switch (errno(termios.tcgetattr(stdout_file.handle, &term_start))) {
        .SUCCESS => {},
        else => return null,
    }

    last_start = term_start;

    var term_raw = term_start;

    term_raw.c_iflag &= @bitCast(~(termios.IGNBRK | termios.BRKINT | termios.PARMRK | termios.ISTRIP | termios.IXON));
    term_raw.c_lflag &= @bitCast(~(termios.ECHO | termios.ECHONL | termios.ICANON | termios.ISIG | termios.IEXTEN));
    term_raw.c_cflag &= @bitCast(~(termios.CSIZE | termios.PARENB));
    term_raw.c_cflag |= @bitCast(termios.CS8);

    return .{
        .start = term_start,
        .raw = term_raw,
    };
}

/// Sets the stdout file's file mode.
pub fn set(stdout_file: File, mode: *const termios.termios) void {
    // dis guard the errno if it fails.
    _ = termios.tcsetattr(stdout_file.handle, 0, mode);
}

pub var last_start: ?termios.termios = null;

/// std library package
const std = @import("std");
const errno = std.os.errno;
const File = std.fs.File;
const isatty = std.os.isatty;

/// glibc termios include
const termios = @cImport(@cInclude("termios.h"));
