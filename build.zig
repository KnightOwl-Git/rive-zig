const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "rive_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    //add rive c++ src files

    lib.addCSourceFile(.{});

    //add rive includes
    lib.addIncludePath(b.path(C_LIB_DIR));

    b.installArtifact(lib);
}

const RIVE_ROOT_DIR = "rive-runtime/src/";
