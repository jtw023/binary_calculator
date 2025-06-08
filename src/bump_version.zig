/// Made to automatically bump the version of the project
/// Author: Jordan Walters

const std = @import("std");

const BumpType = enum {
    major,
    minor,
    patch,
};

const BumpErr = error {
    UnknownBumpType
};

pub fn main() !void {
    const stderr = std.io.getStdErr().writer();
    if (std.os.argv.len != 2) {
        try stderr.print("Expected exactly 2 arguments but got {}.\n", .{std.os.argv.len});
        return;
    }

    const bump_type_raw: [*:0]const u8 = std.os.argv[1];
    const bump_type: BumpType = try parseBumpType(bump_type_raw);
    const bump_num: u2 = switch (bump_type) {
        .major => 0,
        .minor => 1,
        .patch => 2,
    };
    const path: []const u8 = "../build.zig.zon";

    var bytes: [1<<16]u8 = undefined;
    const version_file: []const u8 = try std.fs.cwd().readFile(path, &bytes);
    var line_iter = std.mem.splitScalar(u8, version_file, '\n');
    var found: bool = false;

    var new_version_file: [4307]u8 = undefined;
    var stream = std.io.fixedBufferStream(&new_version_file);
    const writer = stream.writer();
    while (line_iter.next()) |line| {
        if (std.mem.containsAtLeast(u8, line, 1, ".version")) {
            found = true;
            const version_start = std.mem.indexOfScalar(u8, line, '"') orelse continue;
            const version_end = std.mem.lastIndexOfScalar(u8, line, '"') orelse continue;
            const version_slice = line[version_start + 1 .. version_end];
            var ver_parts = std.mem.splitScalar(u8, version_slice, '.');
            var count: u2 = 0;
            var tmp: [3]u2 = undefined;
            while (ver_parts.next()) |part| {
                var parsed_part = try std.fmt.parseInt(u2, part, 10);
                if (count == bump_num) {
                    parsed_part += 1;
                    tmp[count] = parsed_part;
                } else {
                    tmp[count] = parsed_part;
                }
                count += 1;
            }
            try writer.print("    .version = \"{d}.{d}.{d}\",\n", .{tmp[0], tmp[1], tmp[2]});
        } else {
            writer.print("{s}\n", .{line}) catch {
                try writer.print("{s}", .{line});
            };
        }
    }
    // std.debug.print("{s}", .{new_version_file});
    const file = try std.fs.cwd().createFile(path, .{});
    try file.writeAll(&new_version_file);
    file.close();

    if (!found) {
        try stderr.print("No version line found.\n", .{});
    }
}

fn parseBumpType(s: [*:0]const u8) BumpErr!BumpType {
    const slice = std.mem.span(s);
    if (std.mem.eql(u8, slice, "--major")) return .major;
    if (std.mem.eql(u8, slice, "--minor")) return .minor;
    if (std.mem.eql(u8, slice, "--patch")) return .patch;
    return BumpErr.UnknownBumpType;
}
