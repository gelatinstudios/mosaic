
    import core.stdc.stdlib : EXIT_SUCCESS, EXIT_FAILURE, exit;
import std.stdio;

import math;
import vector_math;
import image;

void writeln_var(alias var)() {
    import std.traits;
    writeln(__traits(identifier, var), " = ", var);
}

// TODO: stretch image so there's a discrete number of tiles?????

image make_mosaic(image im, float scale, int row_count, float blend) {
    import std.math : trunc, lrint, ceil;
    
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
    
    v4[] lerp_lut;
    lerp_lut.length = tile_count;
    int lerp_lut_index = 0;
    foreach (iy; 0..row_count) {
        foreach (ix; 0..row_count) {
            int start_x = cast(int) (ix*traversal_width);
            int start_y = cast(int) (iy*traversal_height);
            int end_x = start_x + cast(int) (traversal_width)  + 1;
            int end_y = start_y + cast(int) (traversal_height) + 1;
            
            end_x = clamp_upper(end_x, im.width-1);
            end_y = clamp_upper(end_y, im.height-1);
            
            // TODO: this should never change, hoist this out
            int pixel_count = (end_x - start_x)*(end_y - start_y);
            
            v4 acc = v4(0, 0, 0, 0);
            foreach(y; start_y..end_y) {
                foreach (x; start_x..end_x) {
                    acc += im.get_pixel(x, y).rgba_to_v4;
                }
            }
            
            lerp_lut[lerp_lut_index++] = acc*(1.0f/pixel_count);
        }
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
            
            float src_x = u * (im.width-1);
            float src_y = v * (im.height-1);
            
            int texel_x = cast(int) src_x;
            int texel_y = cast(int) src_y;
            
            float tx = src_x - texel_x;
            float ty = src_y - texel_y;
            
            v4 texel_a = im.get_pixel(texel_x, texel_y).rgba_to_v4;
            v4 texel_b = im.get_pixel(texel_x + 1, texel_y).rgba_to_v4;
            v4 texel_c = im.get_pixel(texel_x, texel_y + 1).rgba_to_v4;
            v4 texel_d = im.get_pixel(texel_x + 1, texel_y + 1).rgba_to_v4;
            
            v4 output = lerp(lerp(texel_a, tx, texel_b), ty, lerp(texel_c, tx, texel_d));
            int lerp_index = blend_y*row_count + blend_x;
            *dest++ = lerp(output, blend, lerp_lut[lerp_index]).v4_to_rgba;
        }
    }
    
    return result;
}

struct cmd_options {
    float scale = 1.0f;
    int count = 20;
    float blend = 0.5f;
    
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
            ++i;
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
    
    image mosaic = make_mosaic(im, cmd.scale, cmd.count, cmd.blend);
    
    mosaic.write_out_image(output, cmd.jpg_quality);
    writeln("out: ", output);
    
    return EXIT_SUCCESS;
}