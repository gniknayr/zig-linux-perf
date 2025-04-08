const std = @import("std");

pub fn build(bob: *std.Build) void {
    const target = bob.standardTargetOptions(.{});
    const optimize = bob.standardOptimizeOption(.{});

    const main_module = bob.createModule(.{
        .root_source_file = bob.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = bob.addExecutable(.{
        .name = "example",
        .root_module = main_module,
    });

    bob.installArtifact(exe);

    const run_cmd = bob.addRunArtifact(exe);
    run_cmd.step.dependOn(bob.getInstallStep());

    const run_step = bob.step("run", "Run the program");

    run_step.dependOn(&run_cmd.step);
}
