const std = @import("std");
const log = @import("./log.zig");
const net = std.net;
const thread = std.Thread;
const Allocator = std.mem.Allocator;
const prime = @import("./prime.zig");

const max_buf = 16384;

pub fn main() !void {
    const port = 8080;
    const listen_address = try net.Address.parseIp4("0.0.0.0", port);

    log.info("listening on port {d}", .{port});
    var server = try listen_address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    while (true) {
        const conn = server.accept() catch break;
        _ = thread.spawn(thread.SpawnConfig{}, handler, .{conn}) catch |err|
            log.info("Error: {}", .{err});
    }

    log.info("shutting down", .{});
}

fn handler(conn: net.Server.Connection) !void {
    log.info("{} connected", .{conn.address});
    defer {
        conn.stream.close();
        log.info("{} disconnected", .{conn.address});
    }

    var buf_reader = std.io.bufferedReader(conn.stream.reader());
    var in_stream = buf_reader.reader();

    var buf: [max_buf]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    while (in_stream.readUntilDelimiterOrEofAlloc(alloc, '\n', buf.len - 1)) |value| {
        const line = value orelse break; // break on eof
        defer alloc.free(line);

        if (line.len == 0) {
            continue;
        }

        log.debug("{}: request: {s}  [size:{}]", .{ conn.address, line, line.len });

        prime.handle(conn, line);
    } else |err| {
        log.err("{}: {}", .{ conn.address, err });
    }
}

test {
    _ = prime;
}
