
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

image make_mosaic(image im, int width, int height, int count, float blend) {
    import std.math : trunc, lrint, ceil;
    
    image result = image_init(width, height);
    
    float area = width*height;
    float aspect_ratio = cast(float) width/height;
    
    float tile_area = area/count;
    float tile_height = square_root(tile_area/aspect_ratio);
    float tile_width  = tile_area/tile_height;
    
    int x_tile_count = cast(int) ceil(width/tile_width);
    int y_tile_count = cast(int) ceil(height/tile_height);
    
    v4[] lerp_lut;
    for (float ty = 0.0f; ty < im.height; ty += tile_height) {
        for (float tx = 0.0f; tx < im.width; tx += tile_width) {
            int start_x = cast(int) tx;
            int start_y = cast(int) ty;
            int end_x = start_x + cast(int) tile_width;
            int end_y = start_y + cast(int) tile_height;
            
            end_x = clamp_upper(end_x, im.width - 1);
            end_y = clamp_upper(end_y, im.height - 1);
            
            v4 acc = v4(0, 0, 0, 0);
            int acc_count = 0;
            foreach(y; start_y..end_y) {
                foreach (x; start_x..end_x) {
                    acc_count++;
                    acc += im.get_pixel(x, y).rgba_to_v4;
                }
            }
            
            lerp_lut ~= acc*(1.0f/acc_count);
        }
    }
    
    uint *dest = result.pixels;
    foreach (y; 0..height) {
        foreach (x; 0..width) {
            float u = x / (tile_width);
            float v = y / (tile_height);
            
            int blend_x = cast(int) u;
            int blend_y = cast(int) v;
            
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
            int lerp_index = blend_y*x_tile_count + blend_x;
            *dest++ = lerp(output, blend, lerp_lut[lerp_index]).v4_to_rgba;
        }
    }
    
    return result;
}

struct cmd_options {
    int width;
    int height;
    int count = 200;
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
    
    if (!cmd.width)  cmd.width  = im.width;
    if (!cmd.height) cmd.height = im.height;
    
    writeln("in: ", input); stdout.flush;
    
    image mosaic = make_mosaic(im, cmd.width, cmd.height, cmd.count, cmd.blend);
    
    mosaic.write_out_image(output, cmd.jpg_quality);
    writeln("out: ", output);
    
    return EXIT_SUCCESS;
}