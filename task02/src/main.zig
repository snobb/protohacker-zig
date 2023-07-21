const std = @import("std");
const net = std.net;
const thread = std.Thread;
const Allocator = std.mem.Allocator;

const log = @import("./log.zig");
const price = @import("./price.zig");
const msg = @import("./msg.zig");

pub fn main() !void {
    var listener = net.StreamServer.init(net.StreamServer.Options{});
    defer listener.deinit();

    const port = 8080;
    try listener.listen(try net.Address.parseIp6("::", port));

    log.info("listening on port {d}", .{port});

    var ara = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = ara.deinit();

    const threadConfig = thread.SpawnConfig{ .allocator = ara.allocator() };
    var store = price.Store.init(ara.allocator());

    while (true) {
        var conn = listener.accept() catch break;
        _ = thread.spawn(threadConfig, price.handle, .{ conn, &store }) catch |err|
            log.err("{} thread error: {}", .{ conn.address, err });
    }

    log.info("shutting down", .{});
}

test {
    _ = price;
    _ = msg;
}
