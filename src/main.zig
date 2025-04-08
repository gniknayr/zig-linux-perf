const std = @import("std");
const zig = @import("zig.zig");

pub fn maybeError(code: usize, debug: []const u8) !void {
    switch (std.os.linux.E.init(code)) {
        .SUCCESS => {},
        else => |e| {
            std.log.err("{s}: {s}", .{ debug, @tagName(e) });
            return error.Linux;
        },
    }
}

pub fn perf_event_group(perf: *zig.os.linux.perf_event_attr, groupfd: std.os.linux.fd_t) !std.os.linux.fd_t {

    // Read that the kernel must be excluded without CAP_PERFMON > 5.8 or CAP_SYS_ADMIN < 5.8
    // Although I couldn't find any anything it would let me measure without perms
    // Also still wants CAP_SYS_ADMIN on 6.8 lol
    perf.flags.exclude_kernel = true;
    perf.flags.exclude_hv = true;
    perf.flags.exclude_idle = true;

    perf.read_format = zig.os.linux.PERF.FORMAT.ALL;

    // Invalid:
    // zig.os.linux.PERF.FORMAT.MAX

    const pid = std.os.linux.getpid();
    {
        const err = std.os.linux.perf_event_open(@ptrCast(perf), pid, -1, groupfd, 0);
        errdefer {
            switch (perf.type) {
                .HARDWARE => {
                    const cfg: zig.os.linux.PERF.COUNT.HW = @enumFromInt(perf.config);
                    std.log.err("{s} {s}", .{ @tagName(perf.type), @tagName(cfg) });
                },
                .SOFTWARE => {
                    const cfg: zig.os.linux.PERF.COUNT.SW = @enumFromInt(perf.config);
                    std.log.err("{s} {s}", .{ @tagName(perf.type), @tagName(cfg) });
                },
                else => {
                    std.log.err("{s} {d}", .{ @tagName(perf.type), perf.config });
                },
            }
        }
        try maybeError(err, "perf_event_open");
        return @truncate(@as(isize, @bitCast(err)));
    }
}

pub inline fn measure_me() void {
    //
}

pub fn main() !void {
    // Create a base event to be group leader then add a few random events

    var perf_event: zig.os.linux.perf_event_attr = .{};
    perf_event.type = .HARDWARE;
    // // testing
    // perf_event.flags.sample_id_all = true;
    // group leader should start disabled so we can add multiple events
    perf_event.flags.disabled = true;
    const fd = try perf_event_group(&perf_event, -1);
    defer {
        const err = std.os.linux.close(fd);
        maybeError(err, "close(fd)") catch unreachable;
    }

    // This supposedly provides an 8byte ID to correlate which event is which, throws NOTTY as is
    // EVENT_IOC_ID is the one OP missing from zig std, feel like I'm missing some key detail
    // var base_id: usize = 0;
    // {
    //     const err = std.os.linux.ioctl(fd, zig.os.linux.PERF.EVENT_IOC.ID, @intFromPtr(&clock_id));
    //     try maybeError(err, "ioctl .ID");
    // }
    // std.log.debug("base id: {d}", .{id});

    // CONTEXT_SWITCHES

    var clock: zig.os.linux.perf_event_attr = .{};
    clock.initSoftware(.CONTEXT_SWITCHES);
    const clock_fd = try perf_event_group(&clock, fd);
    defer {
        const err = std.os.linux.close(clock_fd);
        maybeError(err, "close(clock_fd)") catch unreachable;
    }

    // CACHE_MISSES

    var cache_misses: zig.os.linux.perf_event_attr = .{};
    cache_misses.initHardware(.CACHE_MISSES);
    const cache_misses_fd = try perf_event_group(&cache_misses, fd);
    defer {
        const err = std.os.linux.close(cache_misses_fd);
        maybeError(err, "close(cache_misses_fd)") catch unreachable;
    }

    // Start

    {
        const err = std.os.linux.ioctl(fd, std.os.linux.PERF.EVENT_IOC.RESET, std.os.linux.PERF.IOC_FLAG_GROUP);
        try maybeError(err, "ioctl: .RESET");
    }
    {
        const err = std.os.linux.ioctl(fd, std.os.linux.PERF.EVENT_IOC.ENABLE, std.os.linux.PERF.IOC_FLAG_GROUP);
        try maybeError(err, "ioctl: .ENABLE");
    }
    measure_me();
    {
        const err = std.os.linux.ioctl(fd, std.os.linux.PERF.EVENT_IOC.DISABLE, std.os.linux.PERF.IOC_FLAG_GROUP);
        try maybeError(err, "ioctl: .DISABLE");
    }

    // Read results from group leader

    const perf_read_group_size = @sizeOf(zig.os.linux.perf_read_group);
    const perf_read_entry_size = @sizeOf(zig.os.linux.perf_read_entry);

    var buf: [4096]u8 = undefined;
    const read = std.os.linux.read(fd, &buf, 4096);
    try maybeError(read, "read");

    std.log.debug("{x}", .{buf[0..read]});

    std.log.debug("perf_read_group {d}", .{perf_read_group_size});
    std.log.debug("perf_read_entry {d}", .{perf_read_entry_size});

    // const read_format: *zig.os.linux.perf_read_group = @alignCast(@ptrCast(&buf));

    var offset: usize = 0;
    const read_format = std.mem.bytesToValue(zig.os.linux.perf_read_group, buf[offset..][0..perf_read_group_size]);
    std.log.debug("{any}", .{read_format});
    offset += perf_read_group_size;

    for (0..read_format.len) |index| {
        _ = index;
        // const read_entry: zig.os.linux.perf_read_entry = read_format.ptr[index];
        const read_entry = std.mem.bytesToValue(zig.os.linux.perf_read_entry, buf[offset..][0..perf_read_entry_size]);
        std.log.debug("{any}", .{read_entry});
        offset += perf_read_entry_size;
    }
}
