const std = @import("std");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, mod: *std.Build.Module) void {
    const upstream = b.dependency("harfbuzz", .{});
    const harfbuzz = b.addLibrary(.{
        .name = "harfbuzz",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            // .link_libc = true,
            .link_libcpp = true,
        }),
    });

    harfbuzz.root_module.addCSourceFiles(.{ .files = &.{
        "hb-aat-layout.cc",
        "hb-aat-map.cc",
        "hb-blob.cc",
        "hb-buffer.cc",
        "hb-common.cc",
        "hb-draw.cc",
        "hb-face-builder.cc",
        "hb-face.cc",
        "hb-font.cc",
        "hb-map.cc",
        "hb-number.cc",
        "hb-ot-cff1-table.cc",
        "hb-ot-cff2-table.cc",
        "hb-ot-color.cc",
        "hb-ot-face.cc",
        "hb-ot-font.cc",
        "hb-ot-layout.cc",
        "hb-ot-map.cc",
        "hb-ot-math.cc",
        "hb-ot-meta.cc",
        "hb-ot-metrics.cc",
        "hb-ot-name.cc",
        "hb-ot-shaper-arabic.cc",
        "hb-ot-shaper-default.cc",
        "hb-ot-shaper-hangul.cc",
        "hb-ot-shaper-hebrew.cc",
        "hb-ot-shaper-indic-table.cc",
        "hb-ot-shaper-indic.cc",
        "hb-ot-shaper-khmer.cc",
        "hb-ot-shaper-myanmar.cc",
        "hb-ot-shaper-syllabic.cc",
        "hb-ot-shaper-thai.cc",
        "hb-ot-shaper-use.cc",
        "hb-ot-shaper-vowel-constraints.cc",
        "hb-ot-shape-fallback.cc",
        "hb-ot-shape-normalize.cc",
        "hb-ot-shape.cc",
        "hb-ot-tag.cc",
        "hb-ot-var.cc",
        "hb-set.cc",
        "hb-shape-plan.cc",
        "hb-shape.cc",
        "hb-shaper.cc",
        "hb-static.cc",
        "hb-ucd.cc",
        "hb-unicode.cc",
        "hb-vector.cc",
        "hb-paint.cc",
        "hb-paint-bounded.cc",
        "hb-paint-extents.cc",
        "hb-outline.cc",
        "hb-style.cc",
        "OT/Var/VARC/VARC.cc",
    }, .root = upstream.path("src") });

    harfbuzz.root_module.addCMacro("HB_ONLY_ONE_SHAPER", "");
    harfbuzz.root_module.addCMacro("HAVE_OT", "");
    harfbuzz.root_module.addCMacro("HB_DISABLE_DEPRECATED", "");
    harfbuzz.root_module.addCMacro("HB_NO_BUFFER_SERIALIZE", "");
    harfbuzz.root_module.addCMacro("HB_NO_BUFFER_VERIFY", "");
    harfbuzz.root_module.addCMacro("HB_NO_BUFFER_MESSAGE", "");

    harfbuzz.root_module.addCMacro("HB_NO_FALLBACK_SHAPE", "");
    harfbuzz.root_module.addCMacro("HB_NO_WIN1256", "");
    harfbuzz.root_module.addCMacro("HB_NO_VERTICAL", "");
    harfbuzz.root_module.addCMacro("HB_NO_MATH", "");
    harfbuzz.root_module.addCMacro("HB_NO_BASE", "");
    harfbuzz.root_module.addCMacro("HB_NO_OT_SHAPE_FRACTIONS", "");
    harfbuzz.root_module.addCMacro("HB_NO_OT_SHAPE_FALLBACK", "");
    harfbuzz.root_module.addCMacro("HB_NO_LEGACY", "");

    harfbuzz.root_module.addCMacro("HB_NO_LAYOUT_COLLECT_GLYPHS", "");
    harfbuzz.root_module.addCMacro("HB_NO_LAYOUT_RARELY_USED", "");
    harfbuzz.root_module.addCMacro("HB_NO_LAYOUT_UNUSED", "");

    harfbuzz.root_module.addCMacro("HB_NO_OT_FONT_GLYPH_NAMES", "");
    harfbuzz.root_module.addCMacro("HB_NO_HINTING", "");
    harfbuzz.root_module.addCMacro("HB_NO_NAME", "");
    harfbuzz.root_module.addCMacro("HB_NO_META", "");
    harfbuzz.root_module.addCMacro("HB_NO_METRICS", "");
    harfbuzz.root_module.addCMacro("HB_NO_SVG", "");
    harfbuzz.root_module.addCMacro("HB_NO_AVAR2", "");
    harfbuzz.root_module.addCMacro("HB_NO_VAR_HVF", "");
    harfbuzz.root_module.addCMacro("HB_NO_VAR_COMPOSITES", "");

    harfbuzz.root_module.addCMacro("HB_NO_EXTERN_HELPERS", "");
    harfbuzz.root_module.addCMacro("HB_NO_SETLOCALE", "");
    harfbuzz.root_module.addCMacro("HB_NO_MMAP", "");
    harfbuzz.root_module.addCMacro("HB_NO_ATEXIT", "");
    harfbuzz.root_module.addCMacro("HB_NO_ERRNO", "");
    harfbuzz.root_module.addCMacro("HB_NO_GETENV", "");
    harfbuzz.root_module.addCMacro("HB_NO_OPEN", "");
    harfbuzz.root_module.addCMacro("HB_NO_FACE_COLLECT_UNICODES", "");

    harfbuzz.root_module.addCMacro("HB_OPTIMIZE_SIZE", "");
    harfbuzz.root_module.addCMacro("HB_NO_UCD_UNASSIGNED", "");

    // harfbuzz.addIncludePath(upstream.path(""));
    // harfbuzz.addIncludePath(upstream.path("src"));
    mod.addIncludePath(upstream.path("src"));
    mod.linkLibrary(harfbuzz);

    //TODO: Mac only

    // harfbuzz.root_module.addCMacro("HAVE_CORETEXT", "");
    // harfbuzz.root_module.addCSourceFiles(.{
    //     .files = &.{
    //         "hb-coretext.cc",
    //         "hb-coretext-shape.cc",
    //         "hb-coretext-font.cc",
    //     },
    //     .root = upstream.path("src"),
    // });
}
