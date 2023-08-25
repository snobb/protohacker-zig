const std = @import("std");
const Allocator = std.mem.Allocator;

const log = @import("./log.zig");
const udp = @import("./udp.zig");

pub const Store = struct {
    allocator: Allocator,
    records: std.StringHashMap([]const u8),

    pub fn init(allocator: Allocator) Store {
        return .{
            .allocator = allocator,
            .records = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.records.deinit();
    }

    pub fn handleDatagram(self: *@This(), dgram: udp.Datagram) !void {
        if (dgram.data.len > 1000) {
            log.err("request is too big: {}", .{dgram.data.len});
            return;
        }

        const sep = std.mem.indexOf(u8, dgram.data, "=");

        if (sep == null) {
            // get - no equal sign in the payload
            if (std.mem.eql(u8, dgram.data, "version")) {
                _ = try dgram.respond("version=wierd database v1.0");
                return;
            }

            const val = self.get(dgram.data) orelse "";
            if (dgram.data.len + val.len + 1 > 1000) {
                log.err("response is too big: {}", .{dgram.data.len});
                return;
            }

            var msg = std.ArrayList(u8).init(self.allocator);
            defer msg.deinit();

            try msg.writer().print("{s}={s}", .{ dgram.data, val });
            _ = try dgram.respond(msg.items);
        } else {
            try self.insert(dgram.data, sep.?);
        }
    }

    fn get(self: *@This(), data: []const u8) ?[]const u8 {
        const val = self.records.get(data);
        if (val == null) {
            log.info("get: |{s}| => does not exist", .{data});
        } else {
            log.info("get: |{s}| => |{s}|", .{ data, val.? });
        }
        return val;
    }

    fn insert(self: *@This(), data: []const u8, sep: usize) !void {
        const key = try self.allocator.dupe(u8, data[0..sep]);
        const val = try self.allocator.dupe(u8, data[sep + 1 ..]);
        log.info("insert: |{s}| => |{s}|", .{ key, val });
        try self.records.put(key, val);
    }
};
