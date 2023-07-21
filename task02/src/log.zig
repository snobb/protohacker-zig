const std = @import("std");

const pfx = "price";
var m = std.Thread.Mutex{};

pub fn info(comptime format: []const u8, args: anytype) void {
    log("info", format, args);
}

pub fn err(comptime format: []const u8, args: anytype) void {
    log("err", format, args);
}

pub fn debug(comptime format: []const u8, args: anytype) void {
    log("debug", format, args);
}

inline fn log(comptime level: []const u8, comptime format: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    m.lock();
    defer m.unlock();
    stdout.print(level ++ "::" ++ pfx ++ ": " ++ format ++ "\n", args) catch return;
}
