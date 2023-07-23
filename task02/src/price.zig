const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Connection = std.net.StreamServer.Connection;

const log = @import("./log.zig");
const message = @import("./msg.zig");

pub const Store = struct {
    payloads: ArrayList(message.Payload),
    allocator: Allocator,
    conn: Connection,

    pub fn init(allocator: Allocator, conn: Connection) Store {
        return Store{
            .allocator = allocator,
            .conn = conn,
            .payloads = ArrayList(message.Payload).init(allocator),
        };
    }

    pub fn handle(self: *@This()) !void {
        var buf_reader = std.io.bufferedReader(self.conn.stream.reader());
        var in_stream = buf_reader.reader();
        var iter = message.ReadIterator{ .stream = in_stream };

        while (try iter.next()) |msg| {
            msg.print(self.conn.address);

            switch (msg.kind) {
                message.kind_insert => try self.payloads.append(msg.payload),

                message.kind_query => {
                    const mean = try self.getAverage(msg.payload.time, msg.payload.data);
                    try message.writeResult(self.conn, mean);
                },

                else => {
                    log.err("{}: Invalid message type: {c}", .{ self.conn.address, msg.kind });
                },
            }
        }
    }

    pub fn getAverage(self: *@This(), time1: i32, time2: i32) !i32 {
        if (time1 > time2) {
            log.err("{}: Invalid time range: {}:{}", .{ self.conn.address, time1, time2 });
            return 0;
        }

        var matches = try ArrayList(f64).initCapacity(self.allocator, self.payloads.items.len);
        defer matches.deinit();

        for (self.payloads.items) |pl| {
            if (pl.time >= time1 and pl.time <= time2) {
                try matches.append(@floatFromInt(pl.data));
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
