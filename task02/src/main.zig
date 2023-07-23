const std = @import("std");
const net = std.net;
const thread = std.Thread;
const Allocator = std.mem.Allocator;
const Connection = std.net.StreamServer.Connection;

const log = @import("./log.zig");
const price = @import("./price.zig");
const msg = @import("./msg.zig");

// Task02 - Means to an End - https://protohackers.com/problem/2
pub fn main() !void {
    var listener = net.StreamServer.init(net.StreamServer.Options{});
    defer listener.deinit();

    const port = 8080;
    try listener.listen(try net.Address.parseIp6("::", port));

    log.info("listening on port {d}", .{port});

    var ara = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = ara.deinit();

    const threadConfig = thread.SpawnConfig{ .allocator = ara.allocator() };

    while (true) {
        var conn = listener.accept() catch break;
        _ = thread.spawn(threadConfig, handler, .{ ara.allocator(), conn }) catch |err|
            log.err("{} thread error: {}", .{ conn.address, err });
    }

    log.info("shutting down", .{});
}

fn handler(allocator: Allocator, conn: Connection) !void {
    log.info("{} connected", .{conn.address});
    defer {
        log.info("{} disconnected", .{conn.address});
        conn.stream.close();
    }

    var store = price.Store.init(allocator, conn);
    try store.handle();
}

test {
    _ = price;
    _ = msg;
}
