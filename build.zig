///based on allyourcodebases/SDL3 and Castholm's version

//TODO: Make options for what to include

//TODO: Next steps: organize and prepare for windows build

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

    //TODO: Prefer releaseSmall
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

    const path_fiddle = b.addExecutable(.{ .name = "path_fiddle", .root_module = b.createModule(.{
        .link_libcpp = true,
        .target = target,
        .optimize = optimize,
    }) });

    const glfw = b.dependency("glfw", .{
        .target = target,
        .optimize = optimize,
    }); //for path fiddle - TODO: organize later

    b.installArtifact(rive_lib);
    b.installArtifact(rive_renderer_lib);
    b.installArtifact(path_fiddle);

    // Set the include path
    rive_mod.addIncludePath(upstream.path("include"));

    //compile Rive source
    rive_mod.addCSourceFiles(.{ .files = &sources.rive_src, .root = upstream.path("src") });
    rive_mod.addCMacro("_RIVE_INTERNAL_", "");
    // rive_mod.addCMacro("RIVE_MACOSX", "");

    //compile Rive Renderer
    // const pls_generated_headers = upstream.path("/renderer/out/include");

    rive_renderer_mod.addIncludePath(upstream.path("include"));
    rive_renderer_mod.addIncludePath(upstream.path("renderer/include"));
    rive_renderer_mod.addIncludePath(upstream.path("renderer/src"));
    rive_renderer_mod.addIncludePath(upstream.path("renderer/glad/include"));
    rive_renderer_mod.addIncludePath(upstream.path("renderer/glad"));
    rive_renderer_mod.addCSourceFiles(.{ .files = &sources.rive_renderer_src, .root = upstream.path("renderer/src"), .flags = &.{"-std=c++20"} }); //Zig's Debug mode will panic if c++ standard isn't set to 20+ due to a negative bitwise shift operation
    rive_renderer_mod.addCSourceFiles(.{ .files = &sources.rive_renderer_metal, .root = upstream.path("renderer/src") });
    rive_renderer_mod.addCSourceFiles(.{ .files = &sources.rive_renderer_gl, .root = upstream.path("renderer/src") });
    rive_renderer_mod.addCSourceFiles(.{ .files = &sources.rive_renderer_glad, .root = upstream.path("renderer/glad") });

    rive_renderer_mod.addCMacro("RIVE_DESKTOP_GL", "");
    rive_renderer_mod.addCMacro("RIVE_MACOSX", "");
    // path_fiddle.root_module.addCMacro("RIVE_DESKTOP_GL", "");

    //TODO: only add -fobj-arc if on mac

    path_fiddle.root_module.addCSourceFiles(.{ .files = &sources.path_fiddle, .root = upstream.path("renderer/path_fiddle"), .flags = &.{"-fobjc-arc"} });
    path_fiddle.linkLibrary(rive_renderer_lib);
    path_fiddle.linkLibrary(rive_lib);

    path_fiddle.step.dependOn(&rive_renderer_lib.step);
    path_fiddle.root_module.linkLibrary(glfw.artifact("glfw"));

    //TODO: figure out how to reuse include paths from the other targets

    path_fiddle.root_module.addIncludePath(upstream.path("include"));
    path_fiddle.root_module.addIncludePath(upstream.path("renderer/include"));
    path_fiddle.root_module.addIncludePath(upstream.path("renderer/src"));
    path_fiddle.root_module.addIncludePath(upstream.path("renderer/glad/include"));
    path_fiddle.root_module.addIncludePath(upstream.path("renderer/glad"));
    path_fiddle.root_module.addIncludePath(b.path("zig-out/include"));
    path_fiddle.root_module.addCMacro("RIVE_DESKTOP_GL", "");
    path_fiddle.root_module.addCMacro("RIVE_MACOSX", "");

    // platform specific links

    if (macos) {
        path_fiddle.root_module.linkFramework("Metal", .{});

        path_fiddle.root_module.linkFramework("Cocoa", .{});
        path_fiddle.root_module.linkFramework("QuartzCore", .{});
        path_fiddle.root_module.linkFramework("IOKit", .{});
        // rive_renderer_mod.linkFramework("OpenGL", .{});
        // path_fiddle.root_module.linkFramework("OpenGL", .{});
    }

    //compile Rive shaders for renderer

    //TODO: see if I can do this directly in zig instead of relying on the makefile

    const make_cmd = b.addSystemCommand(&.{"make"});

    const ply_dep = b.dependency("python_ply", .{});
    const ply_path = ply_dep.path("src/");
    const ply_path_resolved = ply_path.getPath(b);

    const shaders_dir = upstream.path("renderer/src/shaders");
    const shaders_dir_resolved = shaders_dir.getPath(b);

    //TODO: figure out how to use this variable as the include path, see what the rive premake file does
    const pls_generated_headers = b.path("zig-out/include/generated/shaders");
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
        // rive_renderer_mod.linkFramework("metal", .{});
    }
    rive_renderer_lib.step.dependOn(&make_cmd.step);
    rive_renderer_mod.addIncludePath(b.path("zig-out/include"));
}
