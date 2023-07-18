const std = @import("std");
const log = @import("./log.zig");
const Connection = std.net.StreamServer.Connection;
const expect = std.testing.expect;
const expectError = std.testing.expectError;

const Request = struct { method: []const u8, number: f64 };
const Response = struct { method: []const u8, prime: bool };

const RequestError = error{ InvalidMethod, InvalidNumber, MalformedRequest };

const max_buf = 1024;

pub fn handle(conn: Connection, line: []const u8) void {
    const req = parseRequest(line) catch |err| {
        log.debug("error:{}", .{err});
        sendError(conn);
        return;
    };

    sendResult(conn, isPrime(req.number)) catch |err| {
        log.err("failed to send result: {?}\n", .{err});
        return;
    };
}

fn parseRequest(data: []const u8) !Request {
    var stream = std.json.TokenStream.init(data);
    var buf: [max_buf]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);

    const req = std.json.parse(Request, &stream, .{
        .allocator = fba.allocator(),
        .ignore_unknown_fields = true,
    }) catch return RequestError.MalformedRequest;

    try validateRequest(data, req);
    return req;
}

test "parseRequest: should parse the request correctly" {
    var line =
        \\{"method":"isPrime","number":123}
    ;
    const req = try parseRequest(line);

    try expect(std.mem.eql(u8, req.method, "isPrime"));
    try expect(req.number == 123);
}

test "parseRequest: error on string with valid number" {
    var line =
        \\{"method":"isPrime","number":"123"}
    ;
    try expectError(RequestError.InvalidNumber, parseRequest(line));
}

test "parseRequest: should error out on invalid data" {
    var line =
        \\{"method":"isPrime","number":"foo"}
    ;
    try expectError(RequestError.MalformedRequest, parseRequest(line));
}

fn validateRequest(line: []const u8, req: Request) !void {
    if (!std.mem.eql(u8, req.method, "isPrime")) {
        return RequestError.InvalidMethod;
    }

    // Zig JSON parser would parse both number and string containing a valid
    // number as number.
    // Eg. both {"num":123} and {"num":"123"} will be parsed into struct { num: f64 }
    // successfully. Hence need to validate here and return an error on string since it's not
    // allowed by the spec.
    const idx = std.mem.lastIndexOf(u8, line, "\"number\":") orelse
        return RequestError.MalformedRequest;

    for (line[idx + 9 ..]) |ch| {
        switch (ch) {
            ' ' => continue,
            '"' => return RequestError.InvalidNumber,
            else => break, // number
        }
    }
}

test "validateRequest: error on string with valid number" {
    var line =
        \\{"method":"isPrime","number":"123"}
    ;
    const req = Request{ .method = "isPrime", .number = 123 };
    try expectError(RequestError.InvalidNumber, validateRequest(line, req));
}

fn sendError(conn: Connection) void {
    const resp = Response{ .method = "error", .prime = false };
    sendResponse(conn, &resp) catch |err|
        log.err("error: cannot send error {}", .{err});
}

fn sendResult(conn: Connection, result: bool) !void {
    const resp = Response{ .method = "isPrime", .prime = result };
    log.debug("{}:response: prime:{}", .{ conn.address, resp.prime });
    sendResponse(conn, &resp) catch |err|
        log.err("error: cannot send error {}", .{err});
}

fn sendResponse(conn: Connection, resp: *const Response) !void {
    var buf: [max_buf]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var string = std.ArrayList(u8).init(fba.allocator());

    try std.json.stringify(resp, .{}, string.writer());
    _ = try conn.stream.write(string.items);
    _ = try conn.stream.write(&[_]u8{'\n'});
}

fn isPrime(num: f64) bool {
    if (num <= 1) {
        return false;
    }

    // not integer - no prime!
    if (num != std.math.floor(num)) {
        return false;
    }

    const sr = @sqrt(num);
    var i: f64 = 2;

    // TODO: no counting for loops in the current version. Refactor when 0.11 is released.
    while (i <= sr) {
        if (@mod(num, i) == 0) {
            return false;
        }

        i += 1;
    }

    return true;
}

test "isPrime - should return correct values for primes and non-primes" {
    try expect(isPrime(1) == false);
    try expect(isPrime(2) == true);
    try expect(isPrime(3) == true);
    try expect(isPrime(4) == false);
    try expect(isPrime(5) == true);
    try expect(isPrime(6) == false);
    try expect(isPrime(7) == true);
    try expect(isPrime(79) == true);
    try expect(isPrime(80) == false);
}
