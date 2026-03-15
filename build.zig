///based on allyourcodebases/SDL3 and Castholm's version
const std = @import("std");
const util = @import("src/util.zig");
const glob = util.glob;
const InstallArtifactFmt = util.InstallArtifactFmt;

const riveSource = @import("src/rive.zon");

//Libraries Rive depends on
const yoga = @import("src/yoga.zig");
const sheenbidi = @import("src/sheenbidi.zig");
const harfbuzz = @import("src/harfbuzz.zig");
const luau = @import("src/luau.zig");

pub const rive_options = &.{
    "no-scripting",
    "no-layout",
    "no-decoders",
    "no-text",
    "no-audio",
};

pub fn build(b: *std.Build) !void {
    //Rive is being pulled from github here

    const target = b.standardTargetOptions(.{});

    //TODO: Prefer releaseSmall
    const optimize = b.option(
        std.builtin.OptimizeMode,
        "optimize",
        "Optimization mode (default is ReleaseSmall)",
    ) orelse .ReleaseSmall;

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

    //Dependencies

    const glfw = b.dependency("glfw", .{
        //GLFW is needed for path fiddle
        .target = target,
        .optimize = optimize,
    });

    const upstream = b.dependency("rive", .{});

    //********RIVE CORE**********

    // dependency links

    const rive_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .link_libc = true,
    });

    const rive_lib = b.addLibrary(.{
        .name = "rive",
        .root_module = rive_mod,
        .linkage = linkage,
    });

    InstallArtifactFmt(rive_lib);

    //optional dependencies

    //is there a way for both of these functions to use the same parameters?
    yoga.build(b, target, optimize, rive_mod);
    sheenbidi.build(b, target, optimize, rive_mod);
    harfbuzz.build(b, target, optimize, rive_mod);
    try luau.build(b, target, optimize, rive_mod);

    rive_mod.addIncludePath(upstream.path("include"));
    rive_mod.addIncludePath(upstream.path("dependencies"));
    // rive_mod.addIncludePath(upstream.path("scripting"));
    rive_lib.installHeadersDirectory(upstream.path("include"), "", .{ .include_extensions = &.{ ".h", ".hpp" } });

    //compile Rive source
    rive_mod.addCSourceFiles(try glob(b, .{ .root = upstream.path("src"), .allowed_exts = &.{".cpp"}, .recursive = true })); //Zig's Debug mode will panic if c++ standard isn't set to 20+ due to a negative bitwise shift operation
    // rive_mod.addCSourceFiles(.{ .files = &riveSource.rive_src, .root = upstream.path("src") });
    rive_mod.addCMacro("_RIVE_INTERNAL_", "");

    //TODO: Make macros optional

    rive_mod.addCMacro("WITH_RIVE_TEXT", "");
    rive_mod.addCMacro("WITH_RIVE_LAYOUT", "");
    rive_mod.addCMacro("WITH_RIVE_SCRIPTING", "");

    //******RIVE RENDERER*******

    const rive_renderer_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .link_libc = true,
    });

    const rive_renderer_lib = b.addLibrary(.{
        .name = "rive_renderer",
        .root_module = rive_renderer_mod,
        .linkage = linkage,
    });

    InstallArtifactFmt(rive_renderer_lib);

    // Set the include path

    //compile Rive Renderer

    const dx12_headers = b.dependency("directX", .{});

    // rive_renderer_mod.addIncludePath(upstream.path("include"));
    rive_renderer_mod.linkLibrary(rive_lib);
    rive_renderer_mod.addIncludePath(upstream.path("renderer/include"));
    rive_renderer_mod.addIncludePath(upstream.path("renderer/src"));
    rive_renderer_mod.addIncludePath(upstream.path("renderer/glad/include"));
    rive_renderer_mod.addIncludePath(upstream.path("renderer/glad"));

    rive_renderer_lib.installHeadersDirectory(upstream.path("renderer/include"), "", .{ .include_extensions = &.{ ".h", ".hpp" } });
    rive_renderer_lib.installHeadersDirectory(upstream.path("renderer/src"), "", .{ .include_extensions = &.{ ".h", ".hpp" } });
    rive_renderer_lib.installHeadersDirectory(upstream.path("renderer/glad/include"), "", .{});
    rive_renderer_lib.installHeadersDirectory(upstream.path("renderer/glad"), "", .{});

    rive_renderer_mod.addCSourceFiles(try glob(b, .{ .root = upstream.path("renderer/src"), .allowed_exts = &.{".cpp"}, .flags = &.{"-std=c++20"} })); //Zig's Debug mode will panic if c++ standard isn't set to 20+ due to a negative bitwise shift operation
    if (macos) {
        rive_renderer_mod.addCSourceFiles(try glob(b, .{
            .root = upstream.path("renderer/src/metal"),
            .allowed_exts = &.{".mm"},
        }));
    } else if (windows) {
        rive_renderer_mod.addCSourceFiles(try glob(b, .{
            .root = upstream.path("renderer/src/vulkan"),
            .allowed_exts = &.{".mm"},
        }));

        rive_renderer_mod.addCSourceFiles(try glob(b, .{
            .root = upstream.path("renderer/src/d3d"),
            .allowed_exts = &.{".cpp"},
        }));

        rive_renderer_mod.addCSourceFiles(try glob(b, .{
            .root = upstream.path("renderer/src/d3d11"),
            .allowed_exts = &.{".cpp"},
        }));

        rive_renderer_mod.addCSourceFiles(try glob(b, .{
            .root = upstream.path("renderer/src/d3d12"),
            .allowed_exts = &.{".cpp"},
        }));
    } else if (linux) {
        rive_renderer_mod.addCSourceFiles(try glob(b, .{
            .root = upstream.path("renderer/src/vulkan"),
            .allowed_exts = &.{".mm"},
        }));
    }
    rive_renderer_mod.addCSourceFiles(.{ .root = upstream.path("renderer"), .files = &.{
        "src/gl/gl_state.cpp",
        "src/gl/gl_utils.cpp",
        "src/gl/load_store_actions_ext.cpp",
        "src/gl/render_buffer_gl_impl.cpp",
        "src/gl/render_context_gl_impl.cpp",
        "src/gl/render_target_gl.cpp",
        "src/gl/pls_impl_webgl.cpp",
        "src/gl/pls_impl_rw_texture.cpp",
        "glad/src/egl.c",
        "glad/src/gles2.c",
        "glad/glad_custom.c",
    } });

    // platform specific links

    if (macos) {
        rive_renderer_mod.addCMacro("RIVE_MACOSX", "");
        rive_renderer_mod.linkFramework("Metal", .{});
        rive_renderer_mod.linkFramework("Foundation", .{});
    } else if (windows) {
        rive_renderer_mod.addIncludePath(dx12_headers.path("include/directx"));
    } else if (linux) {}
    rive_renderer_mod.addCMacro("RIVE_DESKTOP_GL", "");

    //compile Rive shaders for renderer

    //TODO: see if I can do this directly in zig instead of relying on the makefile

    const make_cmd = b.addSystemCommand(&.{"make"});

    const ply_dep = b.dependency("python_ply", .{});
    const ply_path = ply_dep.path("src");
    const ply_path_resolved = ply_path.getPath(b);
    const shaders_dir = upstream.path("renderer/src/shaders");

    const shaders_dir_resolved = shaders_dir.getPath(b);

    const pls_generated_headers = b.path("zig-out/include/generated/shaders");

    make_cmd.setEnvironmentVariable("PYTHONPATH", ply_path_resolved);

    //construct the make command

    make_cmd.addArg("-C");
    make_cmd.addArg(shaders_dir_resolved);

    const nproc = std.Thread.getCpuCount() catch 1;
    make_cmd.addArg(b.fmt("-j{d}", .{nproc}));

    make_cmd.addPrefixedDirectoryArg("OUT=", pls_generated_headers);
    // make_cmd.addArg(b.fmt("FLAGS='-p {s}'", .{ply_path_resolved}));

    if (macos) {
        make_cmd.addArg("rive_pls_macosx_metallib");
    } else if (windows) {
        make_cmd.addArg("d3d");
        // make_cmd.addArg("spirv");
    } else if (linux) {
        make_cmd.addArg("spirv");
    }
    rive_renderer_lib.step.dependOn(&make_cmd.step);
    rive_renderer_mod.addIncludePath(b.path("zig-out/include"));

    // *****PATH FIDDLE*******

    const path_fiddle = b.addExecutable(.{ .name = "path_fiddle", .root_module = b.createModule(.{
        .link_libcpp = true,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }) });

    InstallArtifactFmt(path_fiddle);

    path_fiddle.root_module.addCSourceFiles(.{
        .files = &.{ "path_fiddle.cpp", "fiddle_context_gl.cpp", "fiddle_context_vulkan.cpp", "fiddle_context_dawn.cpp", "fiddle_context_d3d.cpp", "fiddle_context_d3d12.cpp" },
        .root = upstream.path("renderer/path_fiddle"),
    });

    if (macos) {
        path_fiddle.root_module.addCSourceFiles(.{
            .files = &.{"fiddle_context_metal.mm"},
            .flags = &.{"-fobjc-arc"},
            .root = upstream.path("renderer/path_fiddle"),
        });
    }
    // } else if (linux) {
    //     path_fiddle.root_module.addCSourceFiles(.{
    //         .files = &.{"fiddle_context_vulkan.cpp"},
    //         .root = upstream.path("renderer/path_fiddle"),
    //     });
    // }
    path_fiddle.linkLibrary(rive_renderer_lib);
    path_fiddle.linkLibrary(rive_lib);

    path_fiddle.step.dependOn(&rive_renderer_lib.step);
    path_fiddle.linkLibrary(glfw.artifact("glfw"));

    path_fiddle.root_module.addCMacro("RIVE_DESKTOP_GL", "");
    if (macos) {
        path_fiddle.root_module.addCMacro("RIVE_MACOSX", "");
        path_fiddle.root_module.linkFramework("Metal", .{});
    }

    const run_exe = b.addRunArtifact(path_fiddle);
    const run_step = b.step("run", "Run Path Fiddle");

    run_step.dependOn(&run_exe.step);
}
