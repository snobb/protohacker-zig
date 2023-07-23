const std = @import("std");
const log = @import("./log.zig");
const net = std.net;
const thread = std.Thread;
const Allocator = std.mem.Allocator;
const prime = @import("./prime.zig");

const max_buf = 16384;

pub fn main() !void {
    var listener = net.StreamServer.init(net.StreamServer.Options{});
    const port = 8080;
    try listener.listen(try net.Address.parseIp6("::", port));

    log.info("listening on port {d}", .{port});

    while (true) {
        var conn = listener.accept() catch break;
        _ = thread.spawn(thread.SpawnConfig{}, handler, .{conn}) catch |err|
            log.info("Error: {}", .{err});
    }

    log.info("shutting down", .{});
}

fn handler(conn: net.StreamServer.Connection) !void {
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
