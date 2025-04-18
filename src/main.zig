const builtin = @import("builtin");
const endianess = builtin.cpu.arch.endian();

const std = @import("std");
const linux = @import("linux");

const zig = @import("zig.zig");
const perf_read_group = zig.os.linux.perf_read_group;
const perf_read_entry = zig.os.linux.perf_read_entry;
const perf_event_attr = zig.os.linux.perf_event_attr;

pub inline fn measure_me() void {
    //
}

pub fn main() !void {
    // const pid = linux.getpid();

    // Create a base event to be group leader then add a few random events
    var perf_event: perf_event_attr = .{};
    perf_event.initHardware(.INSTRUCTIONS);
    // // testing
    // perf_event.flags.sample_id_all = true;
    const fd = try perf_event_lead(&perf_event);
    defer close(fd);

    // CONTEXT_SWITCHES

    var clock: perf_event_attr = .{};
    clock.initSoftware(.CONTEXT_SWITCHES);
    const clock_fd = try perf_event_group(&clock, fd);
    defer close(clock_fd);

    // CACHE_MISSES

    var cache_misses: perf_event_attr = .{};
    cache_misses.initHardware(.CACHE_MISSES);
    const cache_misses_fd = try perf_event_group(&cache_misses, fd);
    defer close(cache_misses_fd);

    // Start

    {
        const result = linux.ioctl(fd, linux.PERF.EVENT_IOC.RESET, linux.PERF.IOC_FLAG_GROUP);
        try maybeError(result, "ioctl: .RESET");
    }
    {
        const result = linux.ioctl(fd, linux.PERF.EVENT_IOC.ENABLE, linux.PERF.IOC_FLAG_GROUP);
        try maybeError(result, "ioctl: .ENABLE");
    }
    measure_me();
    {
        const result = linux.ioctl(fd, linux.PERF.EVENT_IOC.DISABLE, linux.PERF.IOC_FLAG_GROUP);
        try maybeError(result, "ioctl: .DISABLE");
    }

    // Read results from group leader

    const perf_read_group_size = @sizeOf(perf_read_group);
    std.log.debug("perf_read_group_size {d}", .{perf_read_group_size});
    const perf_read_entry_size = @sizeOf(perf_read_entry);
    std.log.debug("perf_read_entry_size {d}", .{perf_read_entry_size});

    var buf: [4096]u8 = undefined;
    const read = linux.read(fd, &buf, 4096);
    try maybeError(read, "read");

    std.log.debug("{x}", .{buf[0..read]});

    var stream = std.io.fixedBufferStream(buf[0..read]);
    const reader = stream.reader();

    const group: perf_read_group = try reader.readStructEndian(perf_read_group, endianess);

    std.log.debug("{any}", .{group});

    for (0..group.len) |_| {
        const entry: perf_read_entry = try reader.readStructEndian(perf_read_entry, endianess);
        std.log.debug("{any}", .{entry});
    }

    // This supposedly provides an 8byte ID to correlate which event is which, throws NOTTY as is
    // EVENT_IOC_ID is the one OP missing from zig std, feel like I'm missing some key detail
    var base_id: usize = 0;
    {
        const err = linux.ioctl(fd, .ID, @intFromPtr(&base_id));
        try maybeError(err, "ioctl .ID");
    }
    std.log.debug("base id: {d}", .{base_id});

    // const read_format: *zig.os.linux.perf_read_group = @alignCast(@ptrCast(&buf));

    // var offset: usize = 0;
    // const read_format = std.mem.bytesToValue(zig.os.linux.perf_read_group, buf[offset..][0..perf_read_group_size]);
    // std.log.debug("{any}", .{read_format});
    // offset += perf_read_group_size;

    // for (0..read_format.len) |index| {
    //     const read_entry: zig.os.linux.perf_read_entry = read_format.ptr[index];
    //     // const read_entry = std.mem.bytesToValue(zig.os.linux.perf_read_entry, buf[offset..][0..perf_read_entry_size]);
    //     std.log.debug("{any}", .{read_entry});
    //     offset += perf_read_entry_size;
    // }
}

pub fn perf_event_group(perf: *perf_event_attr, groupfd: linux.fd_t) linux.PerfEventOpenError!linux.fd_t {
    // perf.flags.exclude_kernel = true;
    // perf.flags.exclude_hv = true;
    // perf.flags.exclude_idle = true;
    perf.read_format = zig.os.linux.PERF.FORMAT.ALL;
    return linux.perf_event_open(perf, -1, 0, groupfd, linux.PERF.FLAG.FD_CLOEXEC);
}

pub fn perf_event_lead(perf: *perf_event_attr) linux.PerfEventOpenError!linux.fd_t {
    // group leader should start disabled so we can add multiple events
    perf.flags.disabled = true;
    return perf_event_group(perf, -1);
}
