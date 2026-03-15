const std = @import("std");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, mod: *std.Build.Module) void {
    const upstream = b.dependency("yoga", .{});
    const yoga = b.addLibrary(.{
        .name = "yoga",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
    });

    yoga.root_module.addIncludePath(upstream.path("yoga"));
    yoga.root_module.addCSourceFiles(.{ .files = &.{
        "Utils.cpp",
        "YGConfig.cpp",
        "YGLayout.cpp",
        "YGEnums.cpp",
        "YGNodePrint.cpp",
        "YGNode.cpp",
        "YGValue.cpp",
        "YGStyle.cpp",
        "Yoga.cpp",
        "event/event.cpp",
        "log.cpp",
    }, .root = upstream.path("yoga") });

    yoga.root_module.addIncludePath(upstream.path(""));
    mod.addIncludePath(upstream.path(""));
    mod.linkLibrary(yoga);
}
