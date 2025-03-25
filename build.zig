const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const mzg = b.createModule(.{
        .root_source_file = b.path("src/mzg.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mzg",
        .root_module = mzg,
    });
    b.installArtifact(lib);

    const tests = b.addTest(.{
        .root_source_file = b.path("tests/all.zig"),
    });
    tests.root_module.addImport("mzg", mzg);
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("mzg-test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

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

    const docs = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = lib.getEmittedDocs(),
    });
    const docs_step = b.step("mzg-docs", "Emit documentation");
    docs_step.dependOn(&docs.step);

    const format = b.addFmt(.{
        .check = true,
        .paths = &.{
            "src/",
            "build.zig",
            "build.zig.zon",
            "example.zig",
        },
    });
    const format_step = b.step("mzg-fmt", "Format project");
    format_step.dependOn(&format.step);

    const all = b.step("mzg-all", "Run all steps");
    all.dependOn(test_step);
    all.dependOn(docs_step);
    all.dependOn(format_step);
}
