const std = @import("std");
const mem = std.mem;
const Connection = std.net.StreamServer.Connection;

const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

const log = @import("./log.zig");

pub const kind_insert = 'I';
pub const kind_query = 'Q';
pub const size = 9;

pub const Payload = struct {
    time: i32,
    data: i32,
};

pub const Store = struct {
    kind: u8,
    payload: Payload,

    pub fn toBuf(self: *const @This(), buf: *[size]u8) void {
        buf[0] = self.kind;
        mem.writeIntForeign(i32, buf[1..5], self.payload.time);
        mem.writeIntForeign(i32, buf[5..9], self.payload.data);
    }

    test "toBuf: should write correct message from buffer" {
        const want = [_]u8{
            0x49, // I for insert
            0x00, 0x00, 0x30, 0x39, // 12345
            0x00, 0x00, 0x00, 0x65, // 101
        };

        const msg = Store{
            .kind = 'I',
            .payload = Payload{ .time = 12345, .data = 101 },
        };

        var buf: [size]u8 = undefined;
        msg.toBuf(&buf);

        try expect(mem.eql(u8, &buf, &want));
    }

    pub fn print(self: *const @This(), address: std.net.Address) void {
        const kind = switch (self.kind) {
            'I' => "INS",
            'Q' => "QRY",
            else => "ERR",
        };

        log.info("{} >>> {s} {d} {d}", .{
            address,
            kind,
            self.payload.time,
            self.payload.data,
        });
    }
};

pub fn fromBuf(buf: []const u8) !Store {
    return Store{ .kind = buf[0], .payload = Payload{
        .time = mem.readIntForeign(i32, buf[1..5]),
        .data = mem.readIntForeign(i32, buf[5..9]),
    } };
}

test "fromBuf: should read correct message from buffer" {
    const buf = [_]u8{
        0x49, // I for insert
        0x00, 0x00, 0x30, 0x39, // 12345
        0x00, 0x00, 0x00, 0x65, // 101
    };

    const msg = try fromBuf(&buf);

    try expectEq(msg.kind, 'I');
    try expectEq(msg.payload.time, 12345);
    try expectEq(msg.payload.data, 101);
}

pub const ReadIterator = struct {
    stream: std.io.BufferedReader(4096, std.net.Stream.Reader).Reader,

    pub fn next(self: *@This()) !?Store {
        var buf: [size]u8 = undefined;

        const n = try self.stream.read(&buf);
        if (n == 0) {
            return null;
        }

        return try fromBuf(&buf);
    }
};

pub fn writeResult(conn: Connection, result: i32) !void {
    var w = conn.stream.writer();
    log.info("{} <<< RES {d}", .{ conn.address, result });
    return try w.writeIntForeign(i32, result);
}
