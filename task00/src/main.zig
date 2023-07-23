const std = @import("std");
const net = std.net;
const debug = std.debug;
const thread = std.Thread;

pub fn main() !void {
    var listener = net.StreamServer.init(net.StreamServer.Options{});
    const port = 8080;
    try listener.listen(try net.Address.parseIp4("0.0.0.0", port));
    debug.print("listening on port {d}\n", .{port});

    while (true) {
        var conn = listener.accept() catch break;
        _ = try thread.spawn(thread.SpawnConfig{}, handler, .{conn});
    }
    debug.print("shutting down\n", .{});
}

fn handler(conn: net.StreamServer.Connection) !void {
    var buf: [10]u8 = undefined;

    debug.print("{} connected\n", .{conn.address});
    defer {
        conn.stream.close();
        debug.print("{} disconnected\n", .{conn.address});
    }

    while (true) {
        var n = conn.stream.read(&buf) catch return;
        if (n == 0) return;
        _ = conn.stream.write(buf[0..n]) catch return;
    }
}
