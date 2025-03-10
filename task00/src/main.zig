const std = @import("std");
const net = std.net;
const debug = std.debug;
const thread = std.Thread;
const log = @import("log.zig");

pub fn main() !void {
    const port = 8080;
    const listen_address = try net.Address.parseIp4("0.0.0.0", port);
    debug.print("listening on port {d}\n", .{port});

    var server = try listen_address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    while (true) {
        const conn = server.accept() catch break;
        log.info("accepted connection from {}", .{conn.address});

        _ = try thread.spawn(thread.SpawnConfig{}, handler, .{conn});
    }
    debug.print("shutting down\n", .{});
}

fn handler(conn: net.Server.Connection) !void {
    var buf: [10]u8 = undefined;

    debug.print("{} connected\n", .{conn.address});
    defer {
        conn.stream.close();
        debug.print("{} disconnected\n", .{conn.address});
    }

    while (true) {
        const n = conn.stream.read(&buf) catch return;
        if (n == 0) return;
        _ = conn.stream.write(buf[0..n]) catch return;
    }
}
