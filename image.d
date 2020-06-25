
import math;
import vector_math;

pragma(inline) uint v4_to_rgba(v4 v) {
    uint result = 0;
    result |= (cast(int)(v.r + 0.5f) << 0);
    result |= (cast(int)(v.g + 0.5f) << 8);
    result |= (cast(int)(v.b + 0.5f) << 16);
    result |= (cast(int)(v.a + 0.5f) << 24);
    return result;
}

pragma(inline) v4 rgba_to_v4(uint u) {
    v4 result;
    result.r = cast(ubyte) (u >> 0);
    result.g = cast(ubyte) (u >> 8);
    result.b = cast(ubyte) (u >> 16);
    result.a = cast(ubyte) (u >> 24);
    return result;
}

uint4 v4_lane_to_rgba4(v4_lane v) {
    uint4 result;
    float4 one_half = 0.5f;
    result |=                     (to_uint4(v.r + one_half));
    result |= simd!(XMM.PSLLD, 8) (to_uint4(v.g + one_half));
    result |= simd!(XMM.PSLLD, 16)(to_uint4(v.b + one_half));
    result |= simd!(XMM.PSLLD, 24)(to_uint4(v.a + one_half));
    return result;
}

v4_lane rgba4_to_v4_lane(uint4 u) {
    uint4 mask = 0xff;
    v4_lane result;
    result.r = to_float4(                    (u) & mask);
    result.g = to_float4(simd!(XMM.PSRLD, 8) (u) & mask);
    result.b = to_float4(simd!(XMM.PSRLD, 16)(u) & mask);
    result.a = to_float4(simd!(XMM.PSRLD, 24)(u) & mask);
    return result;
}

struct image {
    int width;
    int height;
    uint *pixels;
}

image image_init(int width, int height) {
    import core.stdc.stdlib : malloc;
    
    image result;
    result.pixels = cast(uint *)malloc(width*height*uint.sizeof);
    result.width = width;
    result.height = height;
    
    return result;
}

uint get_pixel(image im, int x, int y) {
    assert(x >= 0 && x < im.width && y >= 0 && y < im.height);
    return *(im.pixels + im.width*y + x);
}

import core.simd;

uint4 get_pixel4(image im, int4 x, int4 y) {
    // TODO: simd?
    uint4 result;
    static foreach(i; 0..4)
        result.array[i] = *(im.pixels + im.width*y.array[i] + x.array[i]);
    return result;
}

extern (C) ubyte *stbi_load(const char *filename, int *w, int *h, int *channels_in_file, int desired_channels);

image load_image(string filename) {
    import std.string : toStringz;
    
    image result;
    result.pixels = cast(uint *) stbi_load(filename.toStringz, &result.width, &result.height, null, 4);
    return result;
}

extern (C) int stbi_write_png(const char *filename, int w, int h, int comp, const void *data, int stride_in_bytes);
extern (C) int stbi_write_bmp(const char *filename, int w, int h, int comp, const void *data);
extern (C) int stbi_write_tga(const char *filename, int w, int h, int comp, const void *data);
extern (C) int stbi_write_jpg(const char *filename, int w, int h, int comp, const void *data, int quality);

void write_out_image(image im, string filename, int jpg_quality) {
    import std.string : toStringz;
    import std.path : extension;
    import std.stdio : writeln;
    
    const auto ext = filename.extension;
    switch (ext) {
        case ".png": stbi_write_png(filename.toStringz, im.width, im.height, 4, im.pixels, 0);           break;
        case ".bmp": stbi_write_bmp(filename.toStringz, im.width, im.height, 4, im.pixels);              break;
        case ".jpg": stbi_write_jpg(filename.toStringz, im.width, im.height, 4, im.pixels, jpg_quality); break;
        case ".tga": stbi_write_tga(filename.toStringz, im.width, im.height, 4, im.pixels);              break;
        
        // NOTE: extension should have already been checked to be valid by now
        default: assert(0);
    }
}
