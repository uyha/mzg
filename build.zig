const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const mzg = b.createModule(.{
        .root_source_file = b.path("src/mzg.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("mzg", mzg);

    const mzg_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mzg",
        .root_module = mzg,
    });
    b.installArtifact(mzg_lib);

    const mzg_unit_tests = b.addTest(.{
        .root_source_file = b.path("tests/all.zig"),
    });
    mzg_unit_tests.root_module.addImport("mzg", mzg);
    const run_lib_unit_tests = b.addRunArtifact(mzg_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const mzg_example = b.addExecutable(.{
        .name = "mzg-example",
        .root_source_file = b.path("example.zig"),
        .target = target,
        .optimize = optimize,
    });
    mzg_example.root_module.addImport("mzg", mzg);
    b.installArtifact(mzg_example);

    const run_mzg_example = b.addRunArtifact(mzg_example);
    const run_mzg_example_step = b.step("mzg-exampe", "Run the mzg example");
    run_mzg_example_step.dependOn(&run_mzg_example.step);

    const docs_install = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = mzg_lib.getEmittedDocs(),
    });
    const docs_step = b.step("mzg-docs", "Emit documentation");
    docs_step.dependOn(&docs_install.step);
}
