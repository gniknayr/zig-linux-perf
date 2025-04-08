const std = @import("std");

pub const os = struct {
    pub const linux = struct {
        /// Result struct from perf_event_open() when ALL read flags are set
        /// If PERF_FORMAT_GROUP was specified else see `perf_read_format`
        pub const perf_read_group = extern struct {
            len: u64,
            time_enabled: u64,
            time_running: u64,
            // ptr: [*]const perf_read_entry,
        };

        /// Result value from perf_event_open()
        pub const perf_read_entry = extern struct {
            value: u64,
            id: u64,
            lost: u64,
        };

        /// Result struct from perf_event_open() with ALL except GROUP read flags
        /// If PERF_FORMAT_GROUP was not specified else see `perf_read_group`
        pub const perf_read_format = extern struct {
            value: u64,
            time_enabled: u64,
            time_running: u64,
            id: u64,
            lost: u64,
        };

        // Add PERF_FORMAT_*
        /// https://github.com/torvalds/linux/blob/master/include/uapi/linux/perf_event.h
        pub const PERF = struct {
            pub const TYPE = enum(u32) {
                HARDWARE,
                SOFTWARE,
                TRACEPOINT,
                HW_CACHE,
                RAW,
                BREAKPOINT,
                /// "non-ABI"
                MAX,
                _,
            };

            pub const COUNT = struct {
                pub const HW = enum(u32) {
                    CPU_CYCLES,
                    INSTRUCTIONS,
                    CACHE_REFERENCES,
                    CACHE_MISSES,
                    BRANCH_INSTRUCTIONS,
                    BRANCH_MISSES,
                    BUS_CYCLES,
                    STALLED_CYCLES_FRONTEND,
                    STALLED_CYCLES_BACKEND,
                    REF_CPU_CYCLES,
                    MAX,

                    pub const CACHE = enum(u32) {
                        L1D,
                        L1I,
                        LL,
                        DTLB,
                        ITLB,
                        BPU,
                        NODE,
                        MAX,

                        pub const OP = enum(u32) {
                            READ,
                            WRITE,
                            PREFETCH,
                            MAX,
                        };

                        pub const RESULT = enum(u32) {
                            ACCESS,
                            MISS,
                            MAX,
                        };
                    };
                };

                pub const SW = enum(u32) {
                    CPU_CLOCK,
                    TASK_CLOCK,
                    PAGE_FAULTS,
                    CONTEXT_SWITCHES,
                    CPU_MIGRATIONS,
                    PAGE_FAULTS_MIN,
                    PAGE_FAULTS_MAJ,
                    ALIGNMENT_FAULTS,
                    EMULATION_FAULTS,
                    DUMMY,
                    BPF_OUTPUT,
                    MAX,
                };
            };

            pub const SAMPLE = struct {
                pub const IP = 1;
                pub const TID = 2;
                pub const TIME = 4;
                pub const ADDR = 8;
                pub const READ = 16;
                pub const CALLCHAIN = 32;
                pub const ID = 64;
                pub const CPU = 128;
                pub const PERIOD = 256;
                pub const STREAM_ID = 512;
                pub const RAW = 1024;
                pub const BRANCH_STACK = 2048;
                pub const REGS_USER = 4096;
                pub const STACK_USER = 8192;
                pub const WEIGHT = 16384;
                pub const DATA_SRC = 32768;
                pub const IDENTIFIER = 65536;
                pub const TRANSACTION = 131072;
                pub const REGS_INTR = 262144;
                pub const PHYS_ADDR = 524288;
                pub const MAX = 1048576;

                pub const BRANCH = struct {
                    pub const USER = 1 << 0;
                    pub const KERNEL = 1 << 1;
                    pub const HV = 1 << 2;
                    pub const ANY = 1 << 3;
                    pub const ANY_CALL = 1 << 4;
                    pub const ANY_RETURN = 1 << 5;
                    pub const IND_CALL = 1 << 6;
                    pub const ABORT_TX = 1 << 7;
                    pub const IN_TX = 1 << 8;
                    pub const NO_TX = 1 << 9;
                    pub const COND = 1 << 10;
                    pub const CALL_STACK = 1 << 11;
                    pub const IND_JUMP = 1 << 12;
                    pub const CALL = 1 << 13;
                    pub const NO_FLAGS = 1 << 14;
                    pub const NO_CYCLES = 1 << 15;
                    pub const TYPE_SAVE = 1 << 16;
                    pub const MAX = 1 << 17;
                };
            };

            pub const FLAG = struct {
                pub const FD_NO_GROUP = 1 << 0;
                pub const FD_OUTPUT = 1 << 1;
                pub const PID_CGROUP = 1 << 2;
                pub const FD_CLOEXEC = 1 << 3;
            };

            pub const EVENT_IOC = struct {
                pub const ENABLE = 0x00002400; // _, 0, '$', 0
                pub const DISABLE = 0x00002401; // _, 0, '$', 1
                pub const REFRESH = 0x00002402; // _, 0, '$', 2
                pub const RESET = 0x00002403; // _, 0, '$', 3
                /// Read 8 (u64)
                pub const PERIOD = 0x40_08_24_04; // R, 8, '$', 4
                pub const SET_OUTPUT = 0x00_00_24_05; // _, 0, '$', 5
                /// Write 8 (*u8)
                pub const SET_FILTER = 0x40_08_24_06; // W, 8, '$', 6
                /// Read 8 (*u64)
                pub const ID = 0x20_08_24_07; // R, 8, '$', 7
                /// Write 4 (u32)
                pub const SET_BPF = 0x40_04_24_08; // W, 4, '$', 8
                /// Write 4 (u32)
                pub const PAUSE_OUTPUT = 0x40_04_24_09; // W, 4, '$', 9
                /// Read+Write 8 (*perf_event_query_bpf)
                pub const QUERY_BPF = 0xC0_08_24_0A; // RW, 8, '$', 10
                /// Write 8 (*perf_event_attr)
                pub const MODIFY_ATTRIBUTES = 0x40_08_24_0B; // W, 8, '$', 11
            };

            pub const IOC_FLAG_GROUP = 1;

            pub const FORMAT = struct {
                pub const TIME_ENABLED = 1 << 0;
                pub const TIME_RUNNING = 1 << 1;
                pub const ID = 1 << 2;
                pub const GROUP = 1 << 3;
                pub const LOST = 1 << 4;
                /// Use this flag to fit `perf_read_group` struct
                pub const ALL = TIME_ENABLED | TIME_RUNNING | ID | GROUP | LOST;
                /// "non-ABI"
                pub const MAX = 1 << 5;
            };
        };

        pub const perf_event_attr = extern struct {
            /// Major type: hardware/software/tracepoint/etc.
            type: PERF.TYPE = undefined,
            /// Size of the attr structure, for fwd/bwd compat.
            size: u32 = @sizeOf(perf_event_attr),
            /// Type specific configuration information.
            config: u64 = 0,

            sample_period_or_freq: u64 = 0,
            sample_type: u64 = 0,
            read_format: u64 = 0,

            flags: packed struct {
                /// off by default
                disabled: bool = false,
                /// children inherit it
                inherit: bool = false,
                /// must always be on PMU (Performance Monitoring Unit)
                pinned: bool = false,
                /// only group on PMU (Performance Monitoring Unit)
                exclusive: bool = false,
                /// don't count user
                exclude_user: bool = false,
                /// don't count kernel
                exclude_kernel: bool = false,
                /// don't count hypervisor
                exclude_hv: bool = false,
                /// don't count when idle
                exclude_idle: bool = false,
                /// include mmap data
                mmap: bool = false,
                /// include comm data
                comm: bool = false,
                /// use freq, not period
                freq: bool = false,
                /// per task counts
                inherit_stat: bool = false,
                /// next exec enables
                enable_on_exec: bool = false,
                /// trace fork/exit
                task: bool = false,
                /// wakeup_watermark
                watermark: bool = false,
                /// precise_ip:
                ///
                ///  0 - SAMPLE_IP can have arbitrary skid
                ///  1 - SAMPLE_IP must have constant skid
                ///  2 - SAMPLE_IP requested to have 0 skid
                ///  3 - SAMPLE_IP must have 0 skid
                ///
                ///  See also PERF_RECORD_MISC_EXACT_IP
                /// skid constraint
                precise_ip: u2 = 0,
                /// non-exec mmap data
                mmap_data: bool = false,
                /// sample_type all events
                sample_id_all: bool = false,

                /// don't count in host
                exclude_host: bool = false,
                /// don't count in guest
                exclude_guest: bool = false,

                /// exclude kernel callchains
                exclude_callchain_kernel: bool = false,
                /// exclude user callchains
                exclude_callchain_user: bool = false,
                /// include mmap with inode data
                mmap2: bool = false,
                /// flag comm events that are due to an exec
                comm_exec: bool = false,
                /// use @clockid for time fields
                use_clockid: bool = false,
                /// context switch data
                context_switch: bool = false,
                /// Write ring buffer from end to beginning
                write_backward: bool = false,
                /// include namespaces data
                namespaces: bool = false,

                __reserved_1: u35 = 0,
            } = .{},
            /// wakeup every n events, or
            /// bytes before wakeup
            wakeup_events_or_watermark: u32 = 0,

            bp_type: u32 = 0,

            /// This field is also used for:
            /// bp_addr
            /// kprobe_func for perf_kprobe
            /// uprobe_path for perf_uprobe
            config1: u64 = 0,
            /// This field is also used for:
            /// bp_len
            /// kprobe_addr when kprobe_func == null
            /// probe_offset for perf_[k,u]probe
            config2: u64 = 0,

            /// enum perf_branch_sample_type
            branch_sample_type: u64 = 0,

            /// Defines set of user regs to dump on samples.
            /// See asm/perf_regs.h for details.
            sample_regs_user: u64 = 0,

            /// Defines size of the user stack to dump on samples.
            sample_stack_user: u32 = 0,

            clockid: std.os.linux.clockid_t = .REALTIME,
            /// Defines set of regs to dump for each sample
            /// state captured on:
            ///  - precise = 0: PMU interrupt
            ///  - precise > 0: sampled instruction
            ///
            /// See asm/perf_regs.h for details.
            sample_regs_intr: u64 = 0,

            /// Wakeup watermark for AUX area
            aux_watermark: u32 = 0,
            sample_max_stack: u16 = 0,
            /// Align to u64
            __reserved_2: u16 = 0,

            pub fn initHardware(perf: *perf_event_attr, event: PERF.COUNT.HW) void {
                perf.type = .HARDWARE;
                perf.config = @intFromEnum(event);
            }

            pub fn initSoftware(perf: *perf_event_attr, event: PERF.COUNT.SW) void {
                perf.type = .SOFTWARE;
                perf.config = @intFromEnum(event);
            }
        };
    };
};
