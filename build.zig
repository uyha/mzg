const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const zmgp = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("zmgp", zmgp);

    const zmgp_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zmgp",
        .root_module = zmgp,
    });
    b.installArtifact(zmgp_lib);

    const zmgp_unit_tests = b.addTest(.{
        .root_source_file = b.path("tests/all.zig"),
    });
    zmgp_unit_tests.root_module.addImport("zmgp", zmgp);
    const run_lib_unit_tests = b.addRunArtifact(zmgp_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
