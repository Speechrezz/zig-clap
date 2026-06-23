const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ---Standalone---

    const exe = b.addExecutable(.{
        .name = "test2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addIncludePath(b.path("libraries"));
    exe.root_module.link_libc = true;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the standalone app");
    run_step.dependOn(&run_cmd.step);

    // ---CLAP Plugin---

    const plugin = b.addLibrary(.{
        .name = "test2",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/plugin.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    plugin.root_module.addIncludePath(b.path("libraries"));
    plugin.root_module.link_libc = true;

    // const install_plugin = b.addInstallArtifact(plugin, .{});
    const install_plugin = b.addInstallFileWithDir(
        plugin.getEmittedBin(),
        .bin,
        "test2.clap",
    );

    const clap_step = b.step("clap", "Build the CLAP plugin");
    clap_step.dependOn(&install_plugin.step);

    // ---Tests---

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
