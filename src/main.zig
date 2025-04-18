const builtin = @import("builtin");
const endianess = builtin.cpu.arch.endian();

const std = @import("std");
const linux = @import("linux");

const event_attr = linux.perf.event_attr;
const read_group = linux.perf.read_group;
const read_entry = linux.perf.read_entry;

pub inline fn measure_me() void {
    //
}

pub fn main() !void {
    // const pid = linux.getpid();

    // Create a base event to be group leader then add a few random events
    var perf_event: event_attr = .{};
    perf_event.initHardware(.INSTRUCTIONS);
    // // testing
    // perf_event.flags.sample_id_all = true;
    const fd = try event_lead(&perf_event);
    defer linux.close(fd);

    // CONTEXT_SWITCHES

    var clock: event_attr = .{};
    clock.initSoftware(.CONTEXT_SWITCHES);
    const clock_fd = try event_group(&clock, fd);
    defer linux.close(clock_fd);

    // CACHE_MISSES

    var cache_misses: event_attr = .{};
    cache_misses.initHardware(.CACHE_MISSES);
    const cache_misses_fd = try event_group(&cache_misses, fd);
    defer linux.close(cache_misses_fd);

    // Start

    try linux.perf.ioctlGroup(fd, .RESET);
    try linux.perf.ioctlGroup(fd, .ENABLE);
    measure_me();
    try linux.perf.ioctlGroup(fd, .DISABLE);

    // Read results from group leader

    const read_group_size = @sizeOf(linux.perf.read_group);
    std.log.debug("read_group_size {d}", .{read_group_size});
    const read_entry_size = @sizeOf(linux.perf.read_entry);
    std.log.debug("read_entry_size {d}", .{read_entry_size});

    var buf: [4096]u8 = undefined;
    const read = try linux.read(fd, buf[0..]);

    std.log.debug("{x}", .{buf[0..read]});

    var stream = std.io.fixedBufferStream(buf[0..read]);
    const reader = stream.reader();

    const group: read_group = try reader.readStructEndian(read_group, endianess);

    std.log.debug("{any}", .{group});

    for (0..group.len) |_| {
        const entry: read_entry = try reader.readStructEndian(read_entry, endianess);
        std.log.debug("{any}", .{entry});
    }

    // This supposedly provides an 8byte ID to correlate which event is which, throws NOTTY as is
    // EVENT_IOC_ID is the one OP missing from zig std, feel like I'm missing some key detail
    var base_id: usize = 0;
    try linux.perf.ioctl(fd, .ID, @intFromPtr(&base_id));
    std.log.debug("base id: {d}", .{base_id});

    // const read_format: *linux.perf.read_group = @alignCast(@ptrCast(&buf));

    // var offset: usize = 0;
    // const read_format = std.mem.bytesToValue(read_group, buf[offset..][0..read_group_size]);
    // std.log.debug("{any}", .{read_format});
    // offset += read_group_size;

    // for (0..read_format.len) |index| {
    //     const read_entry: linux.perf.read_entry = read_format.ptr[index];
    //     // const read_entry = std.mem.bytesToValue(read_entry, buf[offset..][0..read_entry_size]);
    //     std.log.debug("{any}", .{read_entry});
    //     offset += read_entry_size;
    // }
}

pub fn event_group(perf: *event_attr, groupfd: linux.fd_t) linux.perf.EventOpenError!linux.fd_t {
    // perf.flags.exclude_kernel = true;
    // perf.flags.exclude_hv = true;
    // perf.flags.exclude_idle = true;
    perf.read_format = linux.perf.FORMAT.ALL;
    return linux.perf.event_open(perf, -1, 0, groupfd, linux.perf.FLAG.FD_CLOEXEC);
}

pub fn event_lead(perf: *event_attr) linux.perf.EventOpenError!linux.fd_t {
    // group leader should start disabled so we can add multiple events
    perf.flags.disabled = true;
    return event_group(perf, -1);
}
