const std = @import("std");
const os = std.os;
const Allocator = std.mem.Allocator;

const bufsz = 4096;

const log = @import("./log.zig");

pub const Datagram = struct {
    allocator: Allocator,
    socket: os.socket_t,
    addr: std.net.Address,
    data: []const u8,

    pub fn free(self: @This()) void {
        self.allocator.free(self.data);
    }

    pub fn respond(self: @This(), buf: []const u8) !usize {
        log.debug("sending {s} to port {}", .{ std.mem.trim(u8, buf, "\n"), self.addr });
        return try os.sendto(self.socket, buf, 0, @ptrCast(&self.addr.any), @sizeOf(@TypeOf(self.addr.any)));
    }
};

pub const Iterator = struct {
    allocator: Allocator,
    socket: os.socket_t,

    pub fn close(self: *@This()) void {
        os.close(self.socket);
    }

    pub fn next(self: *@This()) !?Datagram {
        var caddr: os.sockaddr = std.mem.zeroes(os.sockaddr);
        var caddr_len: os.socklen_t = @sizeOf(std.os.sockaddr.in6);

        var buf: [bufsz]u8 = undefined;
        const size = try os.recvfrom(self.socket, &buf, 0, &caddr, &caddr_len);
        if (size == 0) return null;

        // XXX: probably wrong thing to do, but at least it gets port right and for IPv4 it seems
        // to work completely.
        const addr = std.net.Address{ .any = caddr };

        var data = try self.allocator.dupe(u8, buf[0..size]);

        return .{
            .allocator = self.allocator,
            .socket = self.socket,
            .addr = addr,
            .data = data,
        };
    }
};

pub fn server(allocator: Allocator, addr: []const u8, port: u16) !Iterator {
    const saddr = try std.net.Address.resolveIp(addr, port);
    const inet = saddr.any.family;

    const sock = try os.socket(inet, os.SOCK.DGRAM, 0);
    try os.bind(sock, &saddr.any, saddr.getOsSockLen());

    return .{ .socket = sock, .allocator = allocator };
}
