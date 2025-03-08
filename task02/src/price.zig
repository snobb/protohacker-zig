const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;
const Connection = std.net.Server.Connection;

const log = @import("./log.zig");
const message = @import("./msg.zig");

pub const Store = struct {
    records: HashMap(i32, i32),
    allocator: Allocator,
    conn: Connection,

    pub fn init(allocator: Allocator, conn: Connection) Store {
        return .{
            .allocator = allocator,
            .conn = conn,
            .records = HashMap(i32, i32).init(allocator),
        };
    }

    pub fn handle(self: *@This()) !void {
        var buf_reader = std.io.bufferedReader(self.conn.stream.reader());
        var iter = message.readIterator(buf_reader.reader());

        while (iter.next()) |maybeMsg| {
            const msg = maybeMsg orelse break;

            msg.print(self.conn.address);

            switch (msg) {
                message.Message.insert => try self.records.put(msg.insert.time, msg.insert.price),
                message.Message.query => {
                    const mean = try self.getAverage(msg.query.mintime, msg.query.maxtime);
                    try message.writeResult(self.conn, mean);
                },
            }
        } else |err| {
            log.err("{} || Error: {}", .{ self.conn.address, err });
        }
    }

    pub fn getAverage(self: *@This(), time1: i32, time2: i32) !i32 {
        if (time1 > time2) {
            log.err("{}: Invalid time range: {}:{}", .{ self.conn.address, time1, time2 });
            return 0;
        }

        var matches = try ArrayList(f64).initCapacity(self.allocator, self.records.capacity());
        defer matches.deinit();

        var iter = self.records.iterator();

        while (iter.next()) |item| {
            if (item.key_ptr.* >= time1 and item.key_ptr.* <= time2) {
                try matches.append(@floatFromInt(item.value_ptr.*));
            }
        }

        const avg = computeAverage(matches.items);
        return @intFromFloat(avg);
    }
};

fn computeAverage(data: []f64) f64 {
    if (data.len == 0) {
        return 0;
    }

    var avg: f64 = 0;
    var t: f64 = 1;

    for (data) |n| {
        avg += (n - avg) / t;
        t += 1;
    }

    return avg;
}
