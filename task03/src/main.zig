const std = @import("std");
const net = std.net;
const heap = std.heap;
const thread = std.Thread;
const Allocator = std.mem.Allocator;
const Connection = std.net.Server.Connection;

const log = @import("./log.zig");
const broker = @import("./broker.zig");
const session = @import("./session.zig");

// Task03 - Budget Chat - https://protohackers.com/problem/3
pub fn main() !void {
    const port = 8080;
    const listen_address = try net.Address.parseIp4("0.0.0.0", port);

    log.info("listening on port {d}", .{port});
    var server = try listen_address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    var ara = heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = ara.deinit();

    const threadConfig = thread.SpawnConfig{ .allocator = ara.allocator() };

    var brk = broker.Global.init(ara.allocator());
    defer brk.deinit();

    while (true) {
        const conn = server.accept() catch break;
        _ = thread.spawn(threadConfig, handler, .{ ara.allocator(), conn, &brk }) catch |err|
            log.err("{} thread error: {}", .{ conn.address, err });
    }

    log.info("shutting down", .{});
}

fn handler(allocator: Allocator, conn: Connection, brk: *broker.Global) !void {
    log.info("{} connected", .{conn.address});
    defer {
        log.info("{} disconnected", .{conn.address});
        conn.stream.close();
    }

    var sess = session.Store.init(allocator, brk);
    try sess.handle(conn);
}

test {
    _ = broker;
    _ = session;
}
