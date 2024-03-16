const std = @import("std");
const os = std.os;
const Allocator = std.mem.Allocator;

const log = @import("./log.zig");
const udp = @import("./udp.zig");
const udb = @import("./udatabase.zig");

const port = 5000;

fn getAddress(allocator: Allocator) []const u8 {
    if (std.process.getEnvVarOwned(allocator, "ADDRESS")) |addr| {
        return addr;
    } else |_| {
        return "0.0.0.0";
    }
}

// Task04 - Unusual database - https://protohackers.com/problem/4
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const addr = getAddress(gpa.allocator());

    log.info("listening on {s}:{d}", .{ addr, port });

    var iter = try udp.server(gpa.allocator(), addr, port);
    defer iter.close();

    var db = udb.Store.init(gpa.allocator());
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
