const builtin = @import("builtin");
const endianess = builtin.cpu.arch.endian();

const std = @import("std");
const linux = std.os.linux;

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

    // This supposedly provides an 8byte ID to correlate which event is which, throws NOTTY as is
    // EVENT_IOC_ID is the one OP missing from zig std, feel like I'm missing some key detail
    // var base_id: usize = 0;
    // {
    //     const err = linux.ioctl(fd, zig.os.linux.PERF.EVENT_IOC.ID, @intFromPtr(&base_id));
    //     try maybeError(err, "ioctl .ID");
    // }
    // std.log.debug("base id: {d}", .{id});

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

pub const PerfEventError = error{

    // Extra bits in config1
    // Cache generalized event parameter is out of range
    // Generalized event setting in kernel is -1
    // Scheduling the events failed (conflict)
    // Too many events
    // Invalid flags setting
    // Invalid parameters in attr
    // frequency setting higher than value set by sysctl
    // specified CPU does not exist
    // non-group leader marked as exclusive or pinned
    Invalid,
    // Expecting: cap_perfmon; Possibly: cap_ipc_lock, cap_sys_ptrace, cap_syslog
    // Original note: Requires root permissions (CAP_SYS_?) or paranoid CPU setting
    Permissions,
    HardwareNotSupported,
    // PERF_SOUREC_STACK_TRACE not supported
    StackTraceNotSupported,
    // PMU interrupt not available and requested sampling
    // Request branch tracing and not available
    // Request low-skid events and not available
    OperationNotSupported,
    // Generalized event set to 0 in kernel
    // Invalid attr.type setting
    NullEvent,
    // attr structure bigger than expected and non-zero
    StructTooBig,
    // Kernel failed while allocating memory
    OutOfMemory,
    Busy,
    // .EAGAIN
    Unexpected,
};

pub fn perf_event_open(perf: *perf_event_attr, pid: linux.pid_t, cpu: i32, groupfd: linux.fd_t, flags: usize) PerfEventError!linux.fd_t {
    const result = linux.perf_event_open(@ptrCast(perf), pid, cpu, groupfd, flags);
    if (builtin.mode == .Debug) {
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
    }
    return switch (linux.E.init(result)) {
        .SUCCESS => @intCast(@as(isize, @bitCast(result))),
        .INVAL => error.Invalid,
        .ACCES => error.Permissions,
        .NOENT => error.NullEvent,
        .NODEV => error.HardwareNotSupported,
        .NOSYS => error.StackTraceNotSupported,
        .OPNOTSUPP => error.OperationNotSupported,
        .@"2BIG" => error.StructTooBig,
        .NOMEM => error.OutOfMemory,
        .BUSY => error.Busy,
        else => |err| unexpected(err, "perf_event_open"),
    };
}

pub fn perf_event_group(perf: *perf_event_attr, groupfd: linux.fd_t) PerfEventError!linux.fd_t {
    // perf.flags.exclude_kernel = true;
    // perf.flags.exclude_hv = true;
    // perf.flags.exclude_idle = true;
    perf.read_format = zig.os.linux.PERF.FORMAT.ALL;
    return perf_event_open(perf, -1, 0, groupfd, linux.PERF.FLAG.FD_CLOEXEC);
}

pub fn perf_event_lead(perf: *perf_event_attr) PerfEventError!linux.fd_t {
    // group leader should start disabled so we can add multiple events
    perf.flags.disabled = true;
    return perf_event_group(perf, -1);
}

pub fn perf_event_ctl(fd: linux.fd_t, ioc: zig.os.linux.PERF.IOC_REQUEST, flags: usize) UnexpectedError!void {
    const result = linux.ioctl(fd, ioc, flags);
    return switch (linux.E.init(result)) {
        .SUCCESS => {},
        // TODO
        else => |err| unexpected(err, "perf_event_ctl"),
    };
}

pub fn close(fd: linux.fd_t) void {
    const result = linux.close(fd);
    maybeError(result, "close") catch {};
}

pub fn maybeError(code: usize, comptime debug: []const u8) UnexpectedError!void {
    return switch (linux.E.init(code)) {
        .SUCCESS => {},
        else => |err| unexpected(err, debug),
    };
}

const UnexpectedError = error{Unexpected};
pub fn unexpected(err: linux.E, comptime debug: []const u8) UnexpectedError {
    if (builtin.mode == .Debug) {
        std.log.err("{s}: {s}", .{ debug, @tagName(err) });
    }
    return error.Unexpected;
}
