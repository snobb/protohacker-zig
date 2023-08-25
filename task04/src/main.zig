const std = @import("std");
const os = std.os;
const Allocator = std.mem.Allocator;

const log = @import("./log.zig");
const udp = @import("./udp.zig");
const udatabase = @import("./udatabase.zig");

// Task04 - Unusual database - https://protohackers.com/problem/4
pub fn main() !void {
    const port = 5000;
    log.info("listening on port {d}", .{port});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var ara = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = gpa.deinit();

    var iter = try udp.server(gpa.allocator(), "0.0.0.0", port);
    defer iter.close();

    var db = udatabase.Store.init(gpa.allocator());
    defer db.deinit();

    while (true) {
        while (iter.next()) |data| {
            const dgram = data orelse continue;
            defer dgram.free();

            log.info("{s} from {?}", .{ std.mem.trim(u8, dgram.data, "\n"), dgram.addr });

            db.handleDatagram(dgram) catch |err| {
                log.err("error handling dgram: {?}", .{err});
            };
        } else |err| {
            log.err("error reading dgram: {?}", .{err});
        }
    }
}
