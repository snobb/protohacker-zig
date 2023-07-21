const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Connection = std.net.StreamServer.Connection;

const log = @import("./log.zig");
const message = @import("./msg.zig");

const PriceError = error{ invalidTimeRange, invalidMessageType };

pub const Store = struct {
    payloads: ArrayList(message.Payload),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Store {
        return Store{ .payloads = ArrayList(message.Payload).init(allocator), .allocator = allocator };
    }

    pub fn addPayload(self: *@This(), payload: message.Payload) !void {
        try self.payloads.append(payload);
    }

    pub fn getAverage(self: @This(), time1: i32, time2: i32) !i32 {
        var matches = ArrayList(f64).init(self.allocator);
        defer matches.deinit();

        for (self.payloads.items) |pl| {
            if (pl.time >= time1 and pl.time <= time2) {
                try matches.append(@floatFromInt(pl.data));
            }
        }

        const avg = computeAverage(matches.items);
        return std.math.lossyCast(i32, avg);
    }
};

pub fn handle(conn: Connection, store: *Store) !void {
    log.info("{} connected", .{conn.address});
    defer {
        log.info("{} disconnected", .{conn.address});
        conn.stream.close();
    }

    var buf_reader = std.io.bufferedReader(conn.stream.reader());
    var in_stream = buf_reader.reader();
    var iter = message.ReadIterator{ .stream = in_stream };

    while (try iter.next()) |msg| {
        msg.print(conn.address);

        switch (msg.kind) {
            'I' => try store.addPayload(msg.payload),

            'Q' => {
                const time1 = msg.payload.time;
                const time2 = msg.payload.data;

                if (time1 > time2) {
                    log.err("{}: Invalid time range: {}:{}", .{ conn.address, time1, time2 });
                    try message.writeResult(conn, 0);
                    continue;
                }

                const mean = try store.getAverage(time1, time2);
                try message.writeResult(conn, mean);
            },

            else => {
                log.err("{}: Invalid message type: {c}", .{ conn.address, msg.kind });
                return PriceError.invalidMessageType;
            },
        }
    }
}

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
