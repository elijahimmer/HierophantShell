const ParseStateTag = enum {
    Normal,
    Escaped,
    EscapeCode,
    EscapeExtended,
    EscapeExtendToDouble,
    EscapeDouble,
};

const ParseState = union(ParseStateTag) {
    Normal: void,
    Escaped: void,
    EscapeCode: void,
    EscapeExtended: u8,
    EscapeExtendToDouble: u8,
    EscapeDouble: struct {
        one: u8,
        two: u8,
    },
};

pub const ReadLineError = error{
    SIGINT,
    EndOfStream, // TODO: include the error that contains this, not just this.
} || os.WriteError || Allocator.Error || os.ReadError;

pub const History = ArrayList(ArrayList(u8));
///
pub fn readline(history: *History, out: anytype) ReadLineError!*ArrayList(u8) {
    try shellPrompt(null, out);
    const stdin = io.getStdIn().reader();

    var cursor_pos: usize = 0;
    var history_idx: usize = history.items.len - 1;

    var line_curr = &history.items[history_idx];

    var parse_state = ParseState{ .Normal = @as(void, undefined) };

    const term_config = term.get(out.file);

    if (term_config) |c| {
        term.set(out.file, &c.raw);
    }

    defer if (term_config) |c| {
        term.set(out.file, &c.start);
    };

    while (true) {
        defer try out.buf.flush();

        const i = stdin.readByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        var print_line = false;

        switch (parse_state) {
            .Normal => {
                if (ascii.isControl(i)) {
                    switch (i) {
                        3 => { // ^C
                            try out.out.print("\n", .{});

                            return error.SIGINT;
                        },
                        27 => { // Escape (^[)
                            parse_state = .Escaped;
                        },
                        '\n' => {
                            try out.out.print("\n", .{});
                            break;
                        },
                        0x7f => { // backspace
                            if (cursor_pos > 0) {
                                cursor_pos -= 1;
                                _ = line_curr.orderedRemove(cursor_pos);

                                print_line = true;
                            }
                        },
                        else => {
                            try out.out.print("{x}", .{i});
                        },
                    }
                } else {
                    try line_curr.insert(cursor_pos, i);

                    cursor_pos +|= 1;
                    if (cursor_pos > line_curr.items.len) {
                        cursor_pos = line_curr.items.len -| 1;
                    }
                    try out.out.print("{c}", .{i});
                    print_line = true;
                }
            },
            .Escaped => {
                switch (i) {
                    '[' => parse_state = .EscapeCode,
                    else => try out.out.print("^[{c}", .{i}),
                }
            },
            .EscapeCode => {
                switch (i) {
                    '0'...'9' => |c| {
                        parse_state = ParseState{ .EscapeExtended = c - '0' };
                        continue;
                    },
                    // up or down
                    'A', 'B' => |c| {
                        if (c == 'A') {
                            history_idx -|= 1;
                        } else {
                            history_idx +|= 1;

                            if (history_idx >= history.items.len) {
                                history_idx = history.items.len -| 1;
                            }
                        }

                        const len_prev = line_curr.items.len;

                        line_curr = &history.items[history_idx];
                        cursor_pos = line_curr.items.len;

                        if (len_prev == 0) {
                            try out.out.print("\u{1B}[0K{s}", .{line_curr.items});
                        } else {
                            try out.out.print("\u{1B}[{}D\u{1B}[0K{s}", .{ len_prev, line_curr.items });
                        }
                    },
                    'C', 'D' => |c| {
                        if (c == 'D') { // Go left
                            if (cursor_pos > 0) {
                                cursor_pos -= 1;
                                try out.out.print("\u{1B}[1D", .{});
                            }
                        } else {
                            cursor_pos +|= 1;

                            if (cursor_pos > line_curr.items.len) {
                                cursor_pos = line_curr.items.len;
                            } else {
                                try out.out.print("\u{1B}[C", .{});
                            }
                        }
                    },
                    else => {
                        try out.out.print("^[[{c}", .{i});
                    },
                }

                parse_state = .Normal;
            },
            .EscapeExtended => |c| {
                switch (i) {
                    '~' => { // Delete
                        if (cursor_pos < line_curr.items.len) {
                            _ = line_curr.orderedRemove(cursor_pos);

                            print_line = true;
                        }
                    },
                    ';' => parse_state = .{ .EscapeExtendToDouble = c },
                    else => try out.out.print("^[[3{c}", .{i}),
                }
                parse_state = .Normal;
            },
            .EscapeExtendToDouble => |c| {
                parse_state = .{ .EscapeDouble = .{ .one = c, .two = i } };
            },
            .EscapeDouble => |a| {
                try out.out.print("^[[{};{}{}", .{ a.one, a.two, i });
            },
        }

        if (print_line) {
            const len = line_curr.items.len - cursor_pos;

            try out.out.print("\u{1B}[0K{s}", .{line_curr.items[cursor_pos..]});

            if (len > 0) {
                try out.out.print("\u{1B}[{}D", .{len});
            }
        }
    }

    return line_curr;
}

/// ./shell_prompt.zig
const shellPrompt = @import("shell_prompt.zig").shellPrompt;

/// ./utils.zig
const utils = @import("utils.zig");

/// ./term.zig
const term = @import("term.zig");

/// std library package
const std = @import("std");
const io = std.io;
const fs = std.fs;
const os = std.os;
const mem = std.mem;
const tty = io.tty;
const ascii = std.ascii;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;
