const std = @import("std");
const util = @import("util.zig");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, mod: *std.Build.Module) void {
    const upstream = b.dependency("libwebp", .{});
    const libwebp = util.addRiveDep(b, "libwebp", target, optimize, .c);

    var ssseFlag: []const []const u8 = &.{};

    if (target.result.os.tag == .windows) {
        ssseFlag = &.{"-mssse3"};
    }

    libwebp.root_module.addIncludePath(upstream.path("libwebp"));
    libwebp.root_module.addCSourceFiles(.{
        .files = &.{
            // common dsp
            "dsp/alpha_processing.c",
            "dsp/cpu.c",
            "dsp/dec.c",
            "dsp/dec_clip_tables.c",
            "dsp/filters.c",
            "dsp/lossless.c",
            "dsp/rescaler.c",
            "dsp/upsampling.c",
            "dsp/yuv.c",

            // encoder dsp
            "dsp/cost.c",
            "dsp/enc.c",
            "dsp/lossless_enc.c",
            "dsp/ssim.c",

            // decoder
            "dec/alpha_dec.c",
            "dec/buffer_dec.c",
            "dec/frame_dec.c",
            "dec/idec_dec.c",
            "dec/io_dec.c",
            "dec/quant_dec.c",
            "dec/tree_dec.c",
            "dec/vp8_dec.c",
            "dec/vp8l_dec.c",
            "dec/webp_dec.c",

            // libwebpdspdecode_sse41_la_SOURCES =
            "dsp/alpha_processing_sse41.c",
            "dsp/dec_sse41.c",
            "dsp/lossless_sse41.c",
            "dsp/upsampling_sse41.c",
            "dsp/yuv_sse41.c",

            // libwebpdspdecode_sse2_la_SOURCES =
            "dsp/alpha_processing_sse2.c",
            "dsp/common_sse2.h",
            "dsp/dec_sse2.c",
            "dsp/filters_sse2.c",
            "dsp/lossless_sse2.c",
            "dsp/rescaler_sse2.c",
            "dsp/upsampling_sse2.c",
            "dsp/yuv_sse2.c",

            // neon sources
            // TODO: define WEBP_HAVE_NEON when we're on a platform that supports it.
            "dsp/alpha_processing_neon.c",
            "dsp/dec_neon.c",
            "dsp/filters_neon.c",
            "dsp/lossless_neon.c",
            "dsp/neon.h",
            "dsp/rescaler_neon.c",
            "dsp/upsampling_neon.c",
            "dsp/yuv_neon.c",

            // libwebpdspdecode_msa_la_SOURCES =
            "dsp/dec_msa.c",
            "dsp/filters_msa.c",
            "dsp/lossless_msa.c",
            "dsp/msa_macro.h",
            "dsp/rescaler_msa.c",
            "dsp/upsampling_msa.c",

            // libwebpdspdecode_mips32_la_SOURCES =
            "dsp/dec_mips32.c",
            "dsp/mips_macro.h",
            "dsp/rescaler_mips32.c",
            "dsp/yuv_mips32.c",

            // libwebpdspdecode_mips_dsp_r2_la_SOURCES =
            "dsp/alpha_processing_mips_dsp_r2.c",
            "dsp/dec_mips_dsp_r2.c",
            "dsp/filters_mips_dsp_r2.c",
            "dsp/lossless_mips_dsp_r2.c",
            "dsp/mips_macro.h",
            "dsp/rescaler_mips_dsp_r2.c",
            "dsp/upsampling_mips_dsp_r2.c",
            "dsp/yuv_mips_dsp_r2.c",

            // libwebpdsp_sse2_la_SOURCES =
            "dsp/cost_sse2.c",
            "dsp/enc_sse2.c",
            "dsp/lossless_enc_sse2.c",
            "dsp/ssim_sse2.c",

            // libwebpdsp_sse41_la_SOURCES =
            "dsp/enc_sse41.c",
            "dsp/lossless_enc_sse41.c",

            // libwebpdsp_neon_la_SOURCES =
            "dsp/cost_neon.c",
            "dsp/enc_neon.c",
            "dsp/lossless_enc_neon.c",

            // libwebpdsp_msa_la_SOURCES =
            "dsp/enc_msa.c",
            "dsp/lossless_enc_msa.c",

            // libwebpdsp_mips32_la_SOURCES =
            "dsp/cost_mips32.c",
            "dsp/enc_mips32.c",
            "dsp/lossless_enc_mips32.c",

            // libwebpdsp_mips_dsp_r2_la_SOURCES =
            "dsp/cost_mips_dsp_r2.c",
            "dsp/enc_mips_dsp_r2.c",
            "dsp/lossless_enc_mips_dsp_r2.c",

            // COMMON_SOURCES =
            "utils/bit_reader_utils.c",
            "utils/bit_reader_utils.h",
            "utils/color_cache_utils.c",
            "utils/filters_utils.c",
            "utils/huffman_utils.c",
            "utils/palette.c",
            "utils/quant_levels_dec_utils.c",
            "utils/rescaler_utils.c",
            "utils/random_utils.c",
            "utils/thread_utils.c",
            "utils/utils.c",

            // ENC_SOURCES =
            "utils/bit_writer_utils.c",
            "utils/huffman_encode_utils.c",
            "utils/quant_levels_utils.c",

            // libwebpdemux_la_SOURCES =
            "demux/anim_decode.c",
            "demux/demux.c",
        },
        .root = upstream.path("src"),
        .flags = ssseFlag,
    });

    libwebp.root_module.addIncludePath(upstream.path(""));
    libwebp.installHeadersDirectory(upstream.path("src"), "", .{});
    // mod.addIncludePath(upstream.path(""));
    mod.linkLibrary(libwebp);
}
