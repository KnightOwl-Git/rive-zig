const std = @import("std");
const Io = std.Io;

pub const GlobOptions = struct {
    root: std.Build.LazyPath,
    allowed_exts: []const []const u8,
    recursive: bool = false,
    flags: []const []const u8 = &.{},
    language: ?std.Build.Module.CSourceLanguage = null,
    prefix: []const u8 = "",
    exclude: []const []const u8 = &.{},
    // sayYesYes: bool = false,
};

///Import tons of c files at once!
pub fn glob(b: *std.Build, options: GlobOptions) !std.Build.Module.AddCSourceFilesOptions {
    var sources: std.ArrayList([]const u8) = .empty;
    const io = b.graph.io;

    var dir = try Io.Dir.cwd().openDir(io, options.root.getPath(b), .{ .iterate = true });

    defer dir.close(io);

    //see if we can not reuse so much code here

    if (options.recursive) {
        var walker = try dir.walk(b.allocator);
        while (try walker.next(io)) |entry| {
            const ext = Io.Dir.path.extension(entry.basename);
            const has_ext = for (options.allowed_exts) |e| {
                if (std.mem.eql(u8, ext, e)) break true;
            } else false;
            const has_prefix = std.mem.startsWith(u8, entry.basename, options.prefix);

            const is_excluded = for (options.exclude) |excluded| {
                if (std.mem.eql(u8, excluded, entry.basename)) break true;
            } else false;

            if (has_ext and has_prefix and !is_excluded) {
                try sources.append(b.allocator, b.dupe(entry.path));
            }
        }
    } else {
        var iterator = dir.iterate();
        while (try iterator.next(io)) |entry| {
            const ext = Io.Dir.path.extension(entry.name);
            const has_ext = for (options.allowed_exts) |e| {
                if (std.mem.eql(u8, ext, e)) break true;
            } else false;
            const has_prefix = std.mem.startsWith(u8, entry.name, options.prefix);
            // if (options.sayYesYes and has_prefix) std.debug.print("fileyesyes: {s} \n", .{entry.name});
            //
            const is_excludeed = for (options.exclude) |excluded| {
                if (std.mem.eql(u8, excluded, entry.name)) break true;
            } else false;

            if (has_ext and has_prefix and !is_excludeed) {
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

pub const linkLang = enum { cpp, c, both, none };

pub fn addRiveDep(b: *std.Build, name: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, langs: linkLang) *std.Build.Step.Compile {
    const dep_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    switch (langs) {
        .c,
        => dep_mod.link_libc = true,
        .cpp,
        => dep_mod.link_libc = true,
        .both => {
            dep_mod.link_libc = true;
            dep_mod.link_libcpp = true;
        },
        .none => {},
    }
    return b.addLibrary(.{
        .name = name,
        .linkage = .static,
        .root_module = dep_mod,
    });
}
