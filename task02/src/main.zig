const std = @import("std");
const net = std.net;
const thread = std.Thread;
const Allocator = std.mem.Allocator;
const Connection = std.net.Server.Connection;

const log = @import("./log.zig");
const price = @import("./price.zig");
const msg = @import("./msg.zig");

// Task02 - Means to an End - https://protohackers.com/problem/2
pub fn main() !void {
    const port = 8080;
    const listen_address = try net.Address.parseIp4("0.0.0.0", port);

    log.info("listening on port {d}", .{port});
    var server = try listen_address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    var ara = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = ara.deinit();

    const threadConfig = thread.SpawnConfig{ .allocator = ara.allocator() };

    while (true) {
        const conn = server.accept() catch break;
        _ = thread.spawn(threadConfig, handler, .{ ara.allocator(), conn }) catch |err|
            log.info("Error: {}", .{err});
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
