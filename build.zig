const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "mzg",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const tests = b.addTest(.{
        .root_source_file = b.path("test/all.zig"),
    });
    tests.root_module.addImport("mzg", lib.root_module);
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    inline for (.{
        "array",
        "default",
        "map",
        "simple",
        "stdin",
        "stdout",
        "stream",
    }) |name| {
        const example = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path("examples/" ++ name ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });
        example.root_module.addImport("mzg", lib.root_module);
        b.installArtifact(example);

        const run_example = b.addRunArtifact(example);
        const run_example_step = b.step(
            name,
            "Run the " ++ name ++ " example",
        );
        run_example_step.dependOn(&run_example.step);
    }

    const docs = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = lib.getEmittedDocs(),
    });
    const docs_step = b.step("docs", "Emit documentation");
    docs_step.dependOn(&docs.step);

    const format = b.addFmt(.{
        .check = true,
        .paths = &.{
            "src/",
            "examples/",
            "test/",
            "build.zig",
            "build.zig.zon",
        },
    });
    const format_step = b.step("fmt", "Format project");
    format_step.dependOn(&format.step);

    const all = b.step("all", "Run all steps");
    all.dependOn(test_step);
    all.dependOn(docs_step);
    all.dependOn(format_step);
}
