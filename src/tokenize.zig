//! Tokenize a string into a list of commands and their inputs/outputs.

pub const TokenizeError = error{
    ManyInputs,
    ManyOutputs,
    ManyInputFiles,
    ManyOutputFiles,
    InvalidInputFile,
    InvalidOutputFile,
} || Allocator.Error;

/// Tokenize a string into a list of commands
/// Caller takes ownership of allocated Command slice
/// TODO: Implement it to follow quotes and other marks like pipes.
pub fn tokenize(allocator: Allocator, input: []const u8) TokenizeError![]const Command {
    var commands = ArrayList(Command).init(allocator);

    var semi_split = mem.splitScalar(u8, input, ';');

    while (semi_split.next()) |semi_post| {
        var pipe_split = mem.splitScalar(u8, semi_post, '|');

        var piped_prev = false;

        while (pipe_split.next()) |pipe_post| {
            var com_input = IOType{ .normal = nil };
            var com_output = IOType{ .normal = nil };

            var file_post = pipe_post;

            {
                var file_input: ?[]const u8 = null;
                var file_output: ?[]const u8 = null;

                const input_pos = mem.indexOf(u8, pipe_post, "<");
                const output_pos = mem.indexOf(u8, pipe_post, ">");

                if (output_pos) |op| {
                    if (mem.indexOf(u8, pipe_post[op + 1 ..], ">")) |_| {
                        return TokenizeError.ManyOutputFiles;
                    }
                }

                if (input_pos) |ip| {
                    if (mem.indexOf(u8, pipe_post[ip + 1 ..], "<")) |_| {
                        return TokenizeError.ManyInputFiles;
                    }

                    if (output_pos) |op| {
                        if (op > ip) {
                            file_post = pipe_post[0..ip];
                            file_input = pipe_post[ip + 1 .. op];
                            file_output = pipe_post[op + 1 ..];
                        } else {
                            file_post = pipe_post[0..op];
                            file_output = pipe_post[op + 1 .. ip];
                            file_input = pipe_post[ip + 1 ..];
                        }
                    } else {
                        file_post = pipe_post[0..ip];
                        com_input = IOType{ .file = pipe_post[ip + 1 ..] };
                    }
                } else if (output_pos) |op| {
                    file_post = pipe_post[0..op];
                    com_output = IOType{ .file = pipe_post[op + 1 ..] };
                }

                if (file_input) |fi| {
                    const file_name = mem.trim(u8, fi, &whitespace);

                    // TODO: detect escaped whitespace
                    if (mem.indexOfAny(u8, file_name, &whitespace)) |_| {
                        return TokenizeError.InvalidInputFile;
                    }

                    com_input = IOType{ .file = file_name };
                }

                if (file_output) |fo| {
                    const file_name = mem.trim(u8, fo, &whitespace);

                    // TODO: detect escaped whitespace
                    if (mem.indexOfAny(u8, file_name, &whitespace)) |_| {
                        return TokenizeError.InvalidOutputFile;
                    }

                    com_output = IOType{ .file = file_name };
                }
            }

            if (piped_prev) {
                if (@as(IOTypeTag, com_input) == IOTypeTag.file) {
                    return TokenizeError.ManyInputs;
                }
                com_input = IOType{ .pipe = nil };
                piped_prev = false;
            }

            if (pipe_split.peek()) |next| {
                if (@as(IOTypeTag, com_output) == IOTypeTag.file) {
                    return TokenizeError.ManyOutputs;
                }

                if (next.len != 0) {
                    com_output = IOType{ .pipe = nil };
                    piped_prev = true;
                }
            }

            var itr = mem.tokenize(u8, file_post, &whitespace);
            var arr = ArrayList([]const u8).init(allocator);

            while (itr.next()) |val| {
                try arr.append(val);
            }

            try commands.append(Command{
                .input = com_input,
                .output = com_output,
                .argv = try arr.toOwnedSlice(),
            });
        }
    }

    return commands.toOwnedSlice();
}

pub fn printError(stdout: anytype, err: TokenizeError) !void {
    const tk = TokenizeError;
    try stdout.print("Failed to parse input {s}: {s}\n", .{ @errorName(err), switch (err) {
        tk.ManyInputs => "A command can only have 1 input",
        tk.ManyOutputs => "A command can only have 1 output",
        tk.ManyInputFiles => "A command can only input to 1 file",
        tk.ManyOutputFiles => "A command can only output to 1 file",
        tk.InvalidInputFile => "Input file name is invalid",
        tk.InvalidOutputFile => "Output file name is invalid",
        error.OutOfMemory => "Out of memory",
    } });
}

test tokenize {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const command = "cat - > bb < aa ; command arg1 | echo --all ; ls bvc";
    const result = try tokenize(alloc, command);

    const in_ls = [_]IOTypeTag{ .file, .normal, .pipe, .normal };
    const out_ls = [_]IOTypeTag{ .file, .pipe, .normal, .normal };
    const argv_ls = [_][2][]const u8{
        [_][]const u8{ "cat", "-" },
        [_][]const u8{ "command", "arg1" },
        [_][]const u8{ "echo", "--all" },
        [_][]const u8{ "ls", "bvc" },
    };

    try expect(result.len == 4);

    for (result, in_ls, out_ls, argv_ls) |res, in, out, argv| {
        try expect(@as(IOTypeTag, res.input) == in);
        try expect(@as(IOTypeTag, res.output) == out);

        try expect(res.argv.len == argv.len);
        for (res.argv, argv) |str, arg| {
            try expect(mem.eql(u8, str, arg));
        }
    }

    try expect(mem.eql(u8, result[0].input.file, "aa"));
    try expect(mem.eql(u8, result[0].output.file, "bb"));
}

test "tokenize errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    try expectError(TokenizeError.ManyInputs, tokenize(alloc, "echo a | cat - < a"));
    try expectError(TokenizeError.ManyOutputs, tokenize(alloc, "cat - > a | echo"));
}

const nil = @as(void, undefined);

/// ./run.zig
const run = @import("./run.zig");
const Command = run.Command;
const IOType = run.IOType;
const IOTypeTag = run.IOTypeTag;

/// std library package
const std = @import("std");
const mem = std.mem;
const os = std.os;
const process = std.process;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const whitespace = std.ascii.whitespace;

const expect = std.testing.expect;
const expectError = std.testing.expectError;
