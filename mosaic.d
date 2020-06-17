
import core.stdc.stdlib : EXIT_SUCCESS, EXIT_FAILURE, exit;
import std.stdio;

import math;
import vector_math;
import image;

void writeln_var(alias var)() {
    import std.traits;
    writeln(__traits(identifier, var), " = ", var);
}

image make_mosaic(image im, float scale, int row_count, float blend, bool flip) {
    import std.math : trunc;
    
    int width  = cast(int) (im.width*scale);
    int height = cast(int) (im.height*scale);
    
    image result = image_init(width, height);
    
    int tile_count = square(row_count);
    
    float area = width*height;
    float aspect_ratio = cast(float) im.width/im.height;
    
    float tile_area = area/tile_count;
    float tile_height = square_root(tile_area/aspect_ratio);
    float tile_width  = tile_area/tile_height;
    
    float traversal_width = tile_width/scale;
    float traversal_height = tile_height/scale;
    
    // TODO: the casting here is a bit dodgy
    
    int pixel_count = cast(int)traversal_width * cast(int)traversal_height;
    
    v4[] lerp_lut;
    lerp_lut.length = tile_count;
    int lerp_lut_index = 0;
    foreach (iy; 0..row_count) {
        foreach (ix; 0..row_count) {
            int start_x = cast(int) (ix*traversal_width);
            int start_y = cast(int) (iy*traversal_height);
            int end_x = start_x + cast(int) (traversal_width);
            int end_y = start_y + cast(int) (traversal_height);
            
            //end_x = clamp_upper(end_x, im.width);
            //end_y = clamp_upper(end_y, im.height);
            
            v4 acc = v4(0, 0, 0, 0);
            float contrib = 1.0f/pixel_count;
            foreach(y; start_y..end_y) {
                foreach (x; start_x..end_x) {
                    acc += im.get_pixel(x, y).rgba_to_v4*contrib;
                }
            }
            
            lerp_lut[lerp_lut_index++] = acc;
        }
    }
    
    v4 cubic_hermite(v4 A, v4 B, v4 C, v4 D, float t) {
        // NOTE: https://www.shadertoy.com/view/MllSzX
        float t2 = t*t;
        float t3 = t*t*t;
        
        v4 a = -A*0.5f + (3.0f*B)*0.5f - (3.0f*C)*0.5f + D*0.5f;
        v4 b = A - (5.0*B)*0.5f + 2.0f*C - D*0.5f;
        v4 c = -A*0.5f + C*0.5f;
        v4 d = B;
        
        return a*t3 + b*t2 + c*t + d;
    }
    
    uint *dest = result.pixels;
    foreach (y; 0..height) {
        foreach (x; 0..width) {
            float u = x / (tile_width);
            float v = y / (tile_height);
            
            int blend_x = cast(int) (u);
            int blend_y = cast(int) (v);
            
            u -= trunc(u);
            v -= trunc(v);
            
            if (flip && (blend_x & 1)) {
                u = 1.0f - u;
            }
            
            float src_x = u * (im.width);
            float src_y = v * (im.height);
            
            clamp(1.0f, &src_x, cast(float) (im.width-3));
            clamp(1.0f, &src_y, cast(float) (im.height-3));
            
            int texel_x = cast(int) src_x;
            int texel_y = cast(int) src_y;
            
            float tx = src_x - texel_x;
            float ty = src_y - texel_y;
            
            v4 texel00 = im.get_pixel(texel_x - 1, texel_y - 1).rgba_to_v4;
            v4 texel10 = im.get_pixel(texel_x + 0, texel_y - 1).rgba_to_v4;
            v4 texel20 = im.get_pixel(texel_x + 1, texel_y - 1).rgba_to_v4;
            v4 texel30 = im.get_pixel(texel_x + 2, texel_y - 1).rgba_to_v4;
            
            v4 texel01 = im.get_pixel(texel_x - 1, texel_y + 0).rgba_to_v4;
            v4 texel11 = im.get_pixel(texel_x + 0, texel_y + 0).rgba_to_v4;
            v4 texel21 = im.get_pixel(texel_x + 1, texel_y + 0).rgba_to_v4;
            v4 texel31 = im.get_pixel(texel_x + 2, texel_y + 0).rgba_to_v4;
            
            v4 texel02 = im.get_pixel(texel_x - 1, texel_y + 1).rgba_to_v4;
            v4 texel12 = im.get_pixel(texel_x + 0, texel_y + 1).rgba_to_v4;
            v4 texel22 = im.get_pixel(texel_x + 1, texel_y + 1).rgba_to_v4;
            v4 texel32 = im.get_pixel(texel_x + 2, texel_y + 1).rgba_to_v4;
            
            v4 texel03 = im.get_pixel(texel_x - 1, texel_y + 2).rgba_to_v4;
            v4 texel13 = im.get_pixel(texel_x + 0, texel_y + 2).rgba_to_v4;
            v4 texel23 = im.get_pixel(texel_x + 1, texel_y + 2).rgba_to_v4;
            v4 texel33 = im.get_pixel(texel_x + 2, texel_y + 2).rgba_to_v4;
            
            v4 texel0x = cubic_hermite(texel00, texel10, texel20, texel30, tx);
            v4 texel1x = cubic_hermite(texel01, texel11, texel21, texel31, tx);
            v4 texel2x = cubic_hermite(texel02, texel12, texel22, texel32, tx);
            v4 texel3x = cubic_hermite(texel03, texel13, texel23, texel33, tx);
            
            v4 output = cubic_hermite(texel0x, texel1x, texel2x, texel3x, ty);
            
            clamp(0.0f, &output, 255.0f);
            
            int lerp_index = blend_y*row_count + blend_x;
            auto output_pixel = v4_to_rgba(lerp(output, blend, lerp_lut[lerp_index]));
            
            *dest++ = output_pixel;
        }
    }
    
    return result;
}

struct cmd_options {
    float scale = 1.0f;
    int count = 20;
    float blend = 0.5f;
    bool flip = false;
    
    int png_comp_level = 8;
    int jpg_quality = 100;
}

extern extern (C) int stbi_write_png_compression_level;

int main(string[] args) {
    import std.path : extension;
    import jt_cmd;
    
    bool check_extension(string filename) {
        string ext = filename.extension;
        return (ext == ".png" ||
                ext == ".bmp" ||
                ext == ".jpg" ||
                ext == ".tga");
    }
    
    auto cmd = args.parse_commandline_arguments!cmd_options;
    stbi_write_png_compression_level = cmd.png_comp_level;
    
    string[] filenames;
    for (size_t i = 1; i < args.length; ++i) {
        const arg = args[i];
        if (arg[0] == '-') {
            if (arg != "-flip") ++i;
            continue;
        }
        filenames ~= arg;
    }
    
    if (filenames.length != 2) {
        writeln("usage: ", args[0], " [input filename] [output filename] -[option [arg]...]");
        return EXIT_FAILURE;
    }
    
    auto input  = filenames[0];
    auto output = filenames[1];
    
    image im = load_image(input);
    
    if (!im.pixels) {
        writeln("trouble loading file: ", input);
        return EXIT_FAILURE;
    }
    
    if (!check_extension(output)) {
        writeln("unknown extension: ", output.extension);
        return EXIT_FAILURE;
    }
    
    writeln("in: ", input); stdout.flush;
    
    image mosaic = make_mosaic(im, cmd.scale, cmd.count, cmd.blend, cmd.flip);
    
    mosaic.write_out_image(output, cmd.jpg_quality);
    writeln("out: ", output);
    
    return EXIT_SUCCESS;
}