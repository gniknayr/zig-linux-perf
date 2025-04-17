
Experimental interface for Linux kernel performance and diagnostic information

**This project is currently in a draft state.**

**It is marked public for feedback/informational purposes.**


Requires privileges
```
chmod o-rwx zig-out/bin/example
setcap "cap_perfmon,cap_ipc_lock,cap_sys_ptrace,cap_syslog=ep" zig-out/bin/example
```
