const std = @import("std");
const Allocator = std.mem.Allocator;
const Connection = std.net.StreamServer.Connection;

const log = @import("./log.zig");
const broker = @import("./broker.zig");

const SessionError = error{NameValidatorError};

const max_line = 1024;

pub const Store = struct {
    allocator: Allocator,
    brk: *broker.Global,

    pub fn init(allocator: Allocator, brk: *broker.Global) Store {
        return .{ .allocator = allocator, .brk = brk };
    }

    pub fn handle(self: *@This(), conn: Connection) !void {
        const w = conn.stream.writer();
        try w.print("Welcome to budgetchat! What shall I call you?\n", .{});

        var iter = lineIterator(self.allocator, conn.stream.reader());
        const id = try iter.next() orelse "";

        validate(id) catch |err| {
            log.err("{} invalid name: {s}", .{ conn.address, id });
            return err;
        };

        self.brk.register(id, conn) catch |err| {
            log.err("{} unable to register name: {s}", .{ conn.address, id });
            return err;
        };
        defer self.brk.unregister(id) catch {
            log.err("{} could not unregister {s}", .{ conn.address, id });
        };

        while (try iter.next()) |line| {
            try self.brk.broadcast(id, "[{s}] {s}\n", .{ id, std.mem.trim(u8, line, " \t\n") });
        }
    }
};

fn validate(id: []const u8) !void {
    if (id.len < 1) {
        return SessionError.NameValidatorError;
    }

    for (id) |ch| {
        if ((ch >= 'a' and ch <= 'z') or
            (ch >= 'A' and ch <= 'Z') or
            (ch >= '0' and ch <= '9'))
            continue;

        return SessionError.NameValidatorError;
    }
}

fn LineIterator(comptime ReadType: type) type {
    return struct {
        stream: ReadType,
        allocator: Allocator,

        pub fn next(self: *@This()) !?[]const u8 {
            return try self.stream.readUntilDelimiterOrEofAlloc(self.allocator, '\n', max_line);
        }
    };
}

fn lineIterator(allocator: Allocator, reader: anytype) LineIterator(@TypeOf(reader)) {
    return .{ .allocator = allocator, .stream = reader };
}
