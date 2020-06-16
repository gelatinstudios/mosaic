
import vector_math;

uint v4_to_rgba(v4 v) {
    import std.math : lrint;
    
    uint result = 0;
    result |= (lrint(v.r));
    result |= (lrint(v.g) << 8);
    result |= (lrint(v.b) << 16);
    result |= (lrint(v.a) << 24);
    return result;
}

v4 rgba_to_v4(uint u) {
    v4 result;
    result.r = cast(ubyte) (u);
    result.g = cast(ubyte) (u >> 8);
    result.b = cast(ubyte) (u >> 16);
    result.a = cast(ubyte) (u >> 24);
    return result;
}

ubyte rgba_get_alpha(uint p) {
    return cast(ubyte) (p >> 24);
}

float get_value(v4 v) {
    import std.algorithm : max;
    return max(v.r, v.g, v.b);
}

float get_value(uint p) {
    __gshared float[1<<24] rgb_value_memo;
    
    float *ptr = &rgb_value_memo[p & 0x00ffffff];
    if (*ptr) return *ptr;
    
    float result = get_value(rgba_to_v4(p));
    *ptr = result;
    return result;
}

uint rgba_2_average(uint a, uint b) {
    return lerp(a.rgba_to_v4, 0.5f, b.rgba_to_v4).v4_to_rgba;
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
