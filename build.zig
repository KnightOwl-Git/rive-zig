///based on allyourcodebases/SDL3
const std = @import("std");

pub const sources = @import("src/rive.zon");

pub const flags = &.{
    "-fwith-rive-scripting",
    "-fwith-rive-layout",
    "-fwith-rive-decoders",
    "-fwith-rive-text",
};

pub fn build(b: *std.Build) void {
    //Rive is being pulled from github here
    const upstream = b.dependency("rive", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage",
        \\whether to build a static or dynamic library, defaults to static
    ) orelse .static;

    // Create the library
    const lib = b.addLibrary(.{
        .name = "rive",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .linkage = linkage,
    });

    b.installArtifact(lib);

    // Set the include path
    lib.root_module.addIncludePath(upstream.path("include"));

    //compile Rive source
    lib.root_module.addCSourceFiles(.{ .files = &sources.rive_src, .root = upstream.path("src") });
    // Compile the generic sources

    //required (I think?) macro for Rive to compile - Or maybe there are some cpp files I'm not supposed to link?
    lib.root_module.addCMacro("_RIVE_INTERNAL_", "");
}
