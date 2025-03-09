const std = @import("std");
const Allocator = std.mem.Allocator;
const Connection = std.net.Server.Connection;

const log = @import("./log.zig");

const BrokerError = error{Foo};

pub const Global = struct {
    allocator: Allocator,
    clients: std.StringHashMap(Connection),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: Allocator) Global {
        return .{
            .allocator = allocator,
            .clients = std.StringHashMap(Connection).init(allocator),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *@This()) void {
        self.clients.deinit();
    }

    pub fn register(self: *@This(), id: []const u8, conn: Connection) !void {
        {
            self.mutex.lock();
            defer self.mutex.unlock();
            try self.clients.put(id, conn);
        }

        try self.broadcast(id, "* {s} has entered the room\n", .{id});

        const ids = try self.getIds(id);
        const w = conn.stream.writer();
        try w.print("* the room contains: {s}\n", .{ids});
    }

    pub fn unregister(self: *@This(), id: []const u8) !void {
        self.mutex.lock();
        _ = self.clients.remove(id);
        self.mutex.unlock();

        try self.broadcast(id, "* {s} has left the room\n", .{id});
    }

    pub fn broadcast(self: *@This(), id: []const u8, comptime fmt: []const u8, args: anytype) !void {
        var iter = self.clients.keyIterator();

        while (iter.next()) |key| {
            if (std.mem.eql(u8, key.*, id)) {
                continue;
            }

            const conn = self.clients.get(key.*) orelse break;

            const w = conn.stream.writer();
            try w.print(fmt, args);
        }
    }

    // must free the returned array once done.
    fn getIds(self: *@This(), exclude: []const u8) ![]const u8 {
        var list = try std.ArrayList([]const u8).initCapacity(self.allocator, self.clients.capacity());
        var iter = self.clients.keyIterator();

        while (iter.next()) |key| {
            if (std.mem.eql(u8, key.*, exclude)) {
                continue;
            }

            try list.append(key.*);
        }

        return std.mem.join(self.allocator, ", ", list.items);
    }
};
