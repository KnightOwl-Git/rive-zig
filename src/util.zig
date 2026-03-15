const std = @import("std");

pub const GlobOptions = struct {
    root: std.Build.LazyPath,
    allowed_exts: []const []const u8,
    recursive: bool = false,
    flags: []const []const u8 = &.{},
    language: ?std.Build.Module.CSourceLanguage = null,
};

///Import tons of c files at once!
pub fn glob(b: *std.Build, options: GlobOptions) !std.Build.Module.AddCSourceFilesOptions {
    var sources: std.ArrayList([]const u8) = .empty;

    var dir = try std.fs.cwd().openDir(options.root.getPath(b), .{ .iterate = true });
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

///Function to sort the install artifacts into folders for each platform
pub fn InstallArtifactFmt(artifact: *std.Build.Step.Compile) void {
    const target = artifact.rootModuleTarget();
    const b = artifact.root_module.owner;
    var prefix: []const u8 = "";

    switch (artifact.kind) {
        .exe => prefix = "bin",
        .lib => prefix = "lib",
        else => prefix = "other",
    }

    const pf_output = b.addInstallArtifact(artifact, .{
        .dest_dir = .{
            .override = .{
                .custom = b.fmt("{s}-{s}/{s}", .{
                    @tagName(target.os.tag),
                    @tagName(target.cpu.arch),
                    prefix,
                }),
            },
        },
    });

    b.getInstallStep().dependOn(&pf_output.step);
}
