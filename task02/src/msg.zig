const std = @import("std");
const mem = std.mem;
const Connection = std.net.StreamServer.Connection;

const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

const log = @import("./log.zig");

pub const MessageError = error{InvalidKind};

pub const kind_insert = 'I';
pub const kind_query = 'Q';
pub const size = 9;

pub const Kind = enum { insert, query };

pub const Message = union(Kind) {
    insert: struct {
        time: i32,
        price: i32,
    },
    query: struct {
        mintime: i32,
        maxtime: i32,
    },

    pub fn toBuf(self: @This(), buf: *[size]u8) void {
        switch (self) {
            Kind.insert => {
                buf[0] = 'I';
                mem.writeIntForeign(i32, buf[1..5], self.insert.time);
                mem.writeIntForeign(i32, buf[5..9], self.insert.price);
            },
            Kind.query => {
                buf[0] = 'Q';
                mem.writeIntForeign(i32, buf[1..5], self.query.mintime);
                mem.writeIntForeign(i32, buf[5..9], self.query.maxtime);
            },
        }
    }

    pub fn print(self: @This(), address: std.net.Address) void {
        switch (self) {
            Kind.insert => log.info("{} >>> {s} {d} {d}", .{
                address,
                "INS",
                self.insert.time,
                self.insert.price,
            }),

            Kind.query => log.info("{} >>> {s} {d} {d}", .{
                address,
                "QRY",
                self.query.mintime,
                self.query.maxtime,
            }),
        }
    }
};

test "toBuf: should write correct message from buffer" {
    const want = [_]u8{
        0x49, // I for insert
        0x00, 0x00, 0x30, 0x39, // 12345
        0x00, 0x00, 0x00, 0x65, // 101
    };

    const msg = Message{ .insert = .{
        .time = 12345,
        .price = 101,
    } };

    var buf: [size]u8 = undefined;
    msg.toBuf(&buf);

    try expect(mem.eql(u8, &buf, &want));
}

pub fn fromBuf(buf: []const u8) !Message {
    const v1 = mem.readIntForeign(i32, buf[1..5]);
    const v2 = mem.readIntForeign(i32, buf[5..9]);

    return switch (buf[0]) {
        kind_insert => Message{ .insert = .{ .time = v1, .price = v2 } },
        kind_query => Message{ .query = .{ .mintime = v1, .maxtime = v2 } },
        else => MessageError.InvalidKind,
    };
}

test "fromBuf: should read correct message from buffer" {
    const buf = [_]u8{
        0x49, // I for insert
        0x00, 0x00, 0x30, 0x39, // 12345
        0x00, 0x00, 0x00, 0x65, // 101
    };

    const msg = try fromBuf(&buf);

    try switch (msg) {
        Kind.insert => {
            try expectEq(msg.insert.time, 12345);
            try expectEq(msg.insert.price, 101);
        },

        Kind.query => expect(false), // must not happen;
    };
}

fn ReadIterator(comptime ReaderType: type) type {
    return struct {
        stream: ReaderType,

        pub fn next(self: *@This()) !?Message {
            var buf: [size]u8 = undefined;

            const n = try self.stream.read(&buf);
            if (n == 0) {
                return null;
            }

            return try fromBuf(&buf);
        }
    };
}

pub fn readIterator(stream: anytype) ReadIterator(@TypeOf(stream)) {
    return .{ .stream = stream };
}

pub fn writeResult(conn: Connection, result: i32) !void {
    var w = conn.stream.writer();
    log.info("{} <<< RES {d}", .{ conn.address, result });
    return try w.writeIntForeign(i32, result);
}
