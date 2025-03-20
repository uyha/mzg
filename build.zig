const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const priority = b.addOptions();
    priority.addOption(
        Priority,
        "priority",
        b.option(
            Priority,
            "pack",
            "Optimize for size or speed when packing",
        ) orelse .speed,
    );

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addOptions("options", priority);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("zimsgpack_lib", lib_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zimsgpack",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    const benchmark = b.addExecutable(.{
        .name = "benchmark",
        .root_source_file = b.path("src/benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(benchmark);

    const run_benchmark = b.addRunArtifact(benchmark);
    if (b.args) |args| {
        for (args) |arg| {
            run_benchmark.addArg(arg);
        }
    }
    b.step("benchmark", "Run benchmark").dependOn(&run_benchmark.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

const Priority = enum { size, speed };
