const ParseStateTag = enum {
    normal,
    escaped, // ^[
    esc_code, // ^[[
    esc_count, // ^[[a
    esc_extend, // ^[[a;
    esc_double, // ^[[a;b
};

const ParseState = union(ParseStateTag) {
    normal: void,
    escaped: void, // ^[
    esc_code: void, // ^[[
    esc_count: u8, // ^[[a
    esc_extend: u8, // ^[[a;
    esc_double: struct { // ^[[a;b
        a: u8,
        b: u8,
    },
};

pub const ReadLineError = error{
    SIGINT,
    EndOfStream, // TODO: include the error that contains this, not just this.
} || os.WriteError || Allocator.Error || os.ReadError;

pub const History = ArrayList(ArrayList(u8));

pub fn readline(history: *History, o: anytype) ReadLineError!*ArrayList(u8) {
    defer o.buf.flush() catch {};
    try shellPrompt(null, o);
    const stdin = io.getStdIn().reader();

    var cursor_pos: usize = 0;
    var history_idx: usize = history.items.len - 1;
    var print_line = false;

    var line_curr = &history.items[history_idx];

    var parse_state = ParseState{ .normal = nil };

    const term_config = term.get(o.file);

    if (term_config) |c| {
        term.set(o.file, &c.raw);
    }

    defer if (term_config) |c| {
        term.set(o.file, &c.start);
    };

    while (true) {
        try o.buf.flush();

        const char = stdin.readByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        switch (parse_state) {
            .normal => { // {char}
                if (ascii.isControl(char)) {
                    switch (char) {
                        3 => { // ^C
                            try o.out.print("\n", .{});

                            return error.SIGINT;
                        },
                        27 => { // Escape (^[)
                            parse_state = .escaped;
                        },
                        '\n' => {
                            try o.out.print("\n", .{});
                            break;
                        },
                        0x7f => { // backspace
                            if (cursor_pos > 0) {
                                cursor_pos -= 1;
                                _ = line_curr.orderedRemove(cursor_pos);

                                print_line = true;
                                try o.out.print("\u{1B}[1D", .{});
                            }
                        },
                        else => {
                            try o.out.print("{x}", .{char});
                        },
                    }
                } else {
                    try line_curr.insert(cursor_pos, char);

                    cursor_pos +|= 1;
                    if (cursor_pos > line_curr.items.len) {
                        cursor_pos = line_curr.items.len -| 1;
                    }

                    try o.out.print("{c}", .{char});
                    print_line = true;
                }
            },
            .escaped => { // ^[{char}
                switch (char) {
                    '[' => parse_state = .{ .esc_code = nil },
                    else => {
                        try o.out.print("^[{c}", .{char});
                        parse_state = .{ .normal = nil };
                    },
                }
            },
            .esc_code => { // ^[[{char}
                parse_state = .{ .normal = nil };
                switch (char) {
                    '0'...'9' => parse_state = .{ .esc_count = char - '0' },
                    'A', 'B' => { // Up and Down Movement
                        if (char == 'A') {
                            history_idx -|= 1;
                        } else {
                            if (history_idx < history.items.len - 1) {
                                history_idx += 1;
                            }
                        }

                        const len_prev = line_curr.items.len;

                        line_curr = &history.items[history_idx];
                        cursor_pos = line_curr.items.len;

                        if (len_prev > 0) {
                            try o.out.print("\u{1B}[{}D", .{len_prev});
                        }
                        try o.out.print("\u{1B}[0K{s}", .{line_curr.items});
                        parse_state = .{ .normal = nil };
                    },
                    'C', 'D' => { // Left and Right movement
                        if (char == 'D') {
                            if (cursor_pos > 0) {
                                cursor_pos -= 1;
                                try o.out.print("\u{1B}[1D", .{});
                            }
                        } else {
                            if (cursor_pos < line_curr.items.len) {
                                cursor_pos += 1;
                                try o.out.print("\u{1B}[1C", .{});
                            }
                        }
                        parse_state = .{ .normal = nil };
                    },
                    else => {
                        try o.out.print("^[[{c}", .{char});
                        parse_state = .{ .normal = nil };
                    },
                }
            },
            .esc_count => { // ^[[a{char}
                switch (char) {
                    ';' => parse_state = .{ .esc_extend = parse_state.esc_count },
                    else => {
                        try o.out.print("^[[{}{c}", .{ parse_state.esc_count, char });
                        parse_state = .{ .normal = nil };
                    },
                }
            },
            .esc_extend => { // ^[[a;{char}
                switch (char) {
                    '0'...'9' => parse_state = .{
                        .esc_double = .{
                            .a = parse_state.esc_extend,
                            .b = char - '0',
                        },
                    },
                    else => {
                        try o.out.print("^[[{};{c}", .{ parse_state.esc_count, char });
                        parse_state = .{ .normal = nil };
                    },
                }
            },
            .esc_double => { // ^[[a;b{char}
                try o.out.print("^[[{};{}{c}", .{ parse_state.esc_double.a, parse_state.esc_double.b, char });
                parse_state = .{ .normal = nil };
            },
        }

        if (print_line) {
            const len = line_curr.items.len - cursor_pos;

            try o.out.print("\u{1B}[0K{s}", .{line_curr.items[cursor_pos..]});

            if (len > 0) {
                try o.out.print("\u{1B}[{}D", .{len});
            }
        }
    }

    return line_curr;
}

const nil = @as(void, undefined);

/// ./shell_prompt.zig
const shellPrompt = @import("shell_prompt.zig").shellPrompt;

/// ./utils.zig
const utils = @import("utils.zig");

/// ./term.zig
const term = @import("term.zig");

/// Std lib
const std = @import("std");
const os = std.os;
const io = std.io;
const ascii = std.ascii;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;
