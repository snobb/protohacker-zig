const std = @import("std");
const net = std.net;
const posix = std.posix;
const Allocator = std.mem.Allocator;

const log = @import("./log.zig");

const bufsz = 16384;

pub const Datagram = struct {
    allocator: Allocator,
    socket: posix.socket_t,
    addr: net.Address,
    rawaddr: posix.sockaddr,
    data: []const u8,

    pub fn init(
        allocator: Allocator,
        socket: posix.socket_t,
        addr: posix.sockaddr,
        data: []const u8,
    ) Datagram {
        return .{
            .allocator = allocator,
            .socket = socket,
            .rawaddr = addr,
            .addr = net.Address{ .any = addr },
            .data = data,
        };
    }

    pub fn free(self: @This()) void {
        self.allocator.free(self.data);
    }

    pub fn respond(self: @This(), buf: []const u8) !usize {
        log.debug("sending {s} to port {}", .{
            std.mem.trim(u8, buf, "\n"),
            &self.addr,
        });
        return try posix.sendto(
            self.socket,
            buf,
            0,
            &self.rawaddr,
            @sizeOf(posix.sockaddr),
        );
    }
};

pub const Iterator = struct {
    allocator: Allocator,
    socket: posix.socket_t,

    pub fn close(self: *@This()) void {
        posix.close(self.socket);
    }

    pub fn next(self: *@This()) !?Datagram {
        var caddr: posix.sockaddr = undefined;
        var caddr_len: posix.socklen_t = @sizeOf(posix.sockaddr);

        var buf: [bufsz]u8 = undefined;
        const size = try posix.recvfrom(
            self.socket,
            buf[0..],
            0,
            &caddr,
            &caddr_len,
        );
        if (size == 0) return null;

        const data = try self.allocator.dupe(u8, buf[0..size]);

        return Datagram.init(
            self.allocator,
            self.socket,
            caddr,
            data,
        );
    }
};

pub fn server(allocator: Allocator, host: []const u8, port: u16) !Iterator {
    const addr = try net.Address.parseIp(host, port);

    const sock = try posix.socket(
        addr.any.family,
        posix.SOCK.DGRAM,
        posix.IPPROTO.UDP,
    );
    try posix.bind(
        sock,
        &addr.any,
        addr.getOsSockLen(),
    );

    return .{
        .socket = sock,
        .allocator = allocator,
    };
}
