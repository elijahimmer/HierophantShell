const ParseState = enum {
    Normal,
    Escaped,
    EscapeCode,
};

///
pub fn readline(allocator: Allocator, history: ArrayList([]const u8), out: utils.Out) ![]const u8 {
    try shellPrompt(null, out);
    const stdin = io.getStdIn().reader();

    var buf = ArrayList(u8).init(allocator);
    defer buf.deinit();

    var parse_state: ParseState = .Normal;
    var history_idx: usize = 0;
    var cursor_pos: usize = 0;

    const term_config = term.get(out.file);

    if (term_config) |c| {
        term.set(out.file, &c.raw);
    }

    defer if (term_config) |c| {
        term.set(out.file, &c.start);
    };

    while (true) {
        const i = stdin.readByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => {
                try out.w.print("Failed to read from stdin: {s}\n", .{@errorName(err)});
                continue;
            },
        };

        switch (parse_state) {
            .Normal => {
                switch (i) {
                    3 => { // handle ^C
                        try out.w.print("\n", .{});
                        return readline(allocator, history, out);
                    },
                    27 => {
                        parse_state = .Escaped;
                        continue;
                    },
                    '\n' => {
                        try out.w.print("\n", .{});
                        break;
                    },
                    else => try buf.insert(cursor_pos, i),
                }
                cursor_pos +|= 1;
                try out.w.print("{c}", .{i});
            },
            .Escaped => {
                if (i == '[') {
                    parse_state = .EscapeCode;
                }
            },
            .EscapeCode => {
                switch (i) {
                    // up or down
                    'A', 'B' => |c| {
                        if (c == 'A') {
                            history_idx +|= 1;

                            if (history_idx >= history.items.len) {
                                history_idx = history.items.len;
                            }
                        } else {
                            history_idx -|= 1;
                        }

                        try out.w.print("\r\u{001b}[0J", .{});
                        try shellPrompt(null, out);

                        if (history.items.len != 0 and history_idx != 0) {
                            try out.w.print("{s}", .{history.items[history_idx - 1]});
                            cursor_pos = history.items[history_idx - 1].len;
                        } else {
                            try out.w.print("{s}", .{buf.items});
                            cursor_pos = buf.items.len;
                        }

                        parse_state = .Normal;
                    },
                    // Left or Right
                    'C', 'D' => |c| {
                        if (c == 'C') {
                            cursor_pos +|= 1;
                            if (cursor_pos > )
                        } else {
                            cursor_pos -|= 1;
                        }
                        try out.w.print("\r\u{001b}[{c}", .{c});

                        parse_state = .Normal;
                    },
                    else => {
                        try out.w.print("ESC[{c}", .{i});

                        parse_state = .Normal;
                    },
                }
            },
        }
    }

    return buf.toOwnedSlice();
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
const mem = std.mem;
const tty = io.tty;
const ascii = std.ascii;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;
