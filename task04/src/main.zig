const std = @import("std");
const os = std.os;
const Allocator = std.mem.Allocator;

const log = @import("./log.zig");
const udp = @import("./udp.zig");

// Task04 - Unusual database - https://protohackers.com/problem/4
pub fn main() !void {
    const port = 5000;
    log.info("listening on port {d}", .{port});

    var ara = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = ara.deinit();

    var iter = try udp.server(ara.allocator(), "0.0.0.0", port);
    defer iter.close();

    while (try iter.next()) |dgram| {
        defer dgram.free();

        log.info("{s} from {?}", .{ std.mem.trim(u8, dgram.data, "\n"), dgram.addr });

        _ = try dgram.respond("ack\n");
    }
}
