pub const RunCommandError = error{
    NoSuchCommand,
} || os.ForkError || process.ExecvError;

/// Run a command given the argv
/// TODO: Implement piping for input and output.
pub fn run_command(allocator: Allocator, argv: []const []const u8) RunCommandError!u32 {
    if (argv.len < 1) {
        return RunCommandError.NoSuchCommand;
    }

    const pid = try os.fork();

    if (pid == 0) {
        var err = process.execv(allocator, argv);

        std.debug.print("{s}: {s}\n", .{ argv[0], switch (err) {
            error.FileNotFound => "command not found",
            else => @errorName(err),
        } });

        utils.exit(.Failure);
    }

    utils.current_process = pid;

    const res = os.waitpid(pid, 0);
    utils.current_process = null;
    return res.status;
}


//   const command = mem.trim(u8, buf.items, &ascii.whitespace);
//
//   if (ascii.eqlIgnoreCase(command, "exit")) {
//       try stdout.writeAll("exiting...\n");
//
//       utils.exit(.Success);
//   }
//
//   if (ascii.eqlIgnoreCase(command, "help")) {
//       try stdout.print("{s}\n", .{strings.HELP_MESSAGE});
//       return;
//   }
//
//   var arg_arr = try tokenize(allocator, command);
//   defer arg_arr.deinit();
//
//   last_status = run_command(allocator, arg_arr.items) catch |err| rcmd: {
//       switch (err) {
//           RunCommandError.NoSuchCommand => {},
//           else => try stdout.print("failed to run command: {s}\n", .{@errorName(err)}),
//       }
//       break :rcmd null;
//   };

/// Tokenize a string into the command's argv
/// TODO: Implement it to follow quotes and other marks like pipes.
pub fn tokenize(allocator: Allocator, input: []const u8) Allocator.Error!ArrayList([]const u8) {
    var itr = mem.tokenize(u8, input, &ascii.whitespace);
    var arr = try ArrayList([]const u8).initCapacity(allocator, 16);

    while (itr.next()) |val| {
        try arr.append(val);
    }

    return arr;
}


/// ./utils.zig
const utils = @import("utils.zig");

/// std library package
const std = @import("std");
const mem = std.mem;
const os = std.os;
const Allocator = mem.Allocator;
const process = std.process;
