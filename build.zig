///based on allyourcodebases/SDL3 and Castholm's version
const std = @import("std");

pub const sources = @import("src/rive.zon");

pub const rive_options = &.{
    "no-scripting",
    "no-layout",
    "no-decoders",
    "no-text",
    "no-audio",
};

pub fn build(b: *std.Build) !void {
    //Rive is being pulled from github here
    const upstream = b.dependency("rive", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var windows = false;
    var linux = false;
    var macos = false;
    switch (target.result.os.tag) {
        .windows => {
            windows = true;
        },
        .linux => {
            linux = true;
        },
        .macos => {
            macos = true;
        },
        else => {},
    }

    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "whether to build a static or dynamic library, defaults to static",
    ) orelse .static;

    const rive_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });

    const rive_renderer_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });

    // Create the libraries
    const rive_lib = b.addLibrary(.{
        .name = "rive",
        .root_module = rive_mod,
        .linkage = linkage,
    });

    const rive_renderer_lib = b.addLibrary(.{
        .name = "rive_renderer",
        .root_module = rive_renderer_mod,
        .linkage = linkage,
    });

    b.installArtifact(rive_lib);
    b.installArtifact(rive_renderer_lib);

    // Set the include path
    rive_mod.addIncludePath(upstream.path("include"));

    //compile Rive source
    rive_mod.addCSourceFiles(.{ .files = &sources.rive_src, .root = upstream.path("src") });
    rive_mod.addCMacro("_RIVE_INTERNAL_", "");

    //compile Rive Renderer
    // const pls_generated_headers = upstream.path("/renderer/out/include");

    rive_renderer_mod.addIncludePath(upstream.path("include"));
    rive_renderer_mod.addIncludePath(upstream.path("renderer/include"));
    rive_renderer_mod.addIncludePath(upstream.path("renderer/src"));

    rive_renderer_mod.addCSourceFiles(.{ .files = &sources.rive_renderer_src, .root = upstream.path("renderer/src") });

    //platform specific links

    // if (macos) {
    //     rive_renderer_mod.linkFramework("Metal", .{});
    //     // rive_renderer_mod.linkFramework("", .{});
    //     // rive_renderer_mod.linkFramework("", .{});
    // }

    //compile Rive shaders for renderer

    //TODO: see if I can do this directly in zig instead of relying on the makefile

    const make_cmd = b.addSystemCommand(&.{"make"});

    const ply_dep = b.dependency("python_ply", .{});
    const ply_path = ply_dep.path("src/");
    const ply_path_resolved = ply_path.getPath(b);

    const shaders_dir = upstream.path("renderer/src/shaders");
    const shaders_dir_resolved = shaders_dir.getPath(b);
    const pls_generated_headers = b.path("zig-out/include");
    // const pls_generated_headers_resolved = pls_generated_headers.getPath(b);

    make_cmd.setEnvironmentVariable("PYTHONPATH", ply_path_resolved);

    //construct the make command

    make_cmd.addArg("-C");
    make_cmd.addArg(shaders_dir_resolved);

    const nproc = std.Thread.getCpuCount() catch 1;
    make_cmd.addArg(b.fmt("-j{d}", .{nproc}));

    make_cmd.addPrefixedDirectoryArg("OUT=", pls_generated_headers);
    make_cmd.addArg(b.fmt("FLAGS='-p {s}'", .{ply_path_resolved}));

    if (macos) {
        make_cmd.addArg("rive_pls_macosx_metallib");
        rive_renderer_mod.linkFramework("metal", .{});
    }
    rive_renderer_lib.step.dependOn(&make_cmd.step);
    rive_renderer_mod.addIncludePath(pls_generated_headers);
}
