///based on allyourcodebases/SDL3 and Castholm's version
const std = @import("std");

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

    //Dependencies

    const glfw = b.dependency("glfw", .{
        //GLFW is needed for path fiddle
        .target = target,
        .optimize = optimize,
    });

    const upstream = b.dependency("rive", .{});

    //********RIVE CORE**********

    const rive_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });

    const rive_lib = b.addLibrary(.{
        .name = "rive",
        .root_module = rive_mod,
        .linkage = linkage,
    });

    b.installArtifact(rive_lib);

    rive_mod.addIncludePath(upstream.path("include"));
    rive_lib.installHeadersDirectory(upstream.path("include"), "", .{ .include_extensions = &.{ ".h", ".hpp" } });

    //compile Rive source
    rive_mod.addCSourceFiles(try glob(b, .{ .root = upstream.path("src"), .allowed_exts = &.{".cpp"}, .recursive = true })); //Zig's Debug mode will panic if c++ standard isn't set to 20+ due to a negative bitwise shift operation
    rive_mod.addCMacro("_RIVE_INTERNAL_", "");

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

    b.installArtifact(rive_renderer_lib);

    // Set the include path

    //compile Rive Renderer

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
    rive_renderer_mod.addCSourceFiles(try glob(b, .{
        .root = upstream.path("renderer/src/metal"),
        .allowed_exts = &.{".mm"},
    }));
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
        rive_renderer_mod.linkFramework("Metal", .{});

        rive_renderer_mod.linkFramework("Cocoa", .{});
        rive_renderer_mod.linkFramework("QuartzCore", .{});
        rive_renderer_mod.linkFramework("IOKit", .{});
    }
    rive_renderer_mod.addCMacro("RIVE_DESKTOP_GL", "");
    rive_renderer_mod.addCMacro("RIVE_MACOSX", "");

    //compile Rive shaders for renderer

    // TODO: See if cross compilation is possible

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
    }
    rive_renderer_lib.step.dependOn(&make_cmd.step);
    rive_renderer_mod.addIncludePath(b.path("zig-out/include"));

    // *****PATH FIDDLE*******

    const path_fiddle = b.addExecutable(.{ .name = "path_fiddle", .root_module = b.createModule(.{
        .link_libcpp = true,
        .target = target,
        .optimize = optimize,
    }) });

    b.installArtifact(path_fiddle);

    //TODO: only add -fobj-arc if on mac
    path_fiddle.root_module.addCSourceFiles(try glob(b, .{ .root = upstream.path("renderer/path_fiddle"), .allowed_exts = &.{ ".cpp", ".mm" }, .flags = &.{"-fobjc-arc"} }));
    path_fiddle.linkLibrary(rive_renderer_lib);
    path_fiddle.linkLibrary(rive_lib);

    path_fiddle.step.dependOn(&rive_renderer_lib.step);
    path_fiddle.linkLibrary(glfw.artifact("glfw"));

    path_fiddle.root_module.addCMacro("RIVE_DESKTOP_GL", "");
    path_fiddle.root_module.addCMacro("RIVE_MACOSX", "");

    //Add a run step that automatically runs Path Fiddle

    const run_exe = b.addRunArtifact(path_fiddle);
    const run_step = b.step("run", "Run Path Fiddle");

    run_step.dependOn(&run_exe.step);
}

pub const GlobOptions = struct {
    root: std.Build.LazyPath,
    allowed_exts: []const []const u8,
    recursive: bool = false,
    flags: []const []const u8 = &.{},
    language: ?std.Build.Module.CSourceLanguage = null,
};

fn glob(b: *std.Build, options: GlobOptions) !std.Build.Module.AddCSourceFilesOptions {
    var sources: std.ArrayList([]const u8) = .empty;

    var dir = try std.fs.cwd().openDir(options.root.getPath(b), .{ .iterate = false });
    defer dir.close();
    if (options.recursive) {
        var walker = try dir.walk(b.allocator);
        while (try walker.next()) |entry| {
            const ext = std.fs.path.extension(entry.basename);
            const include_file = for (options.allowed_exts) |e| {
                if (std.mem.eql(u8, ext, e)) break true;
            } else false;
            if (include_file) {
                try sources.append(b.allocator, b.dupe(entry.path));
            }
        }
    } else {
        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            const ext = std.fs.path.extension(entry.name);
            const include_file = for (options.allowed_exts) |e| {
                if (std.mem.eql(u8, ext, e)) break true;
            } else false;
            if (include_file) {
                try sources.append(b.allocator, b.dupe(entry.name));
            }
        }
    }

    return .{ .files = sources.items, .root = options.root, .flags = options.flags, .language = options.language };
}
