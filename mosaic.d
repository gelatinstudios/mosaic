
import core.stdc.stdlib : EXIT_SUCCESS, EXIT_FAILURE, exit;
import std.stdio;

import math;
import vector_math;
import image;

void writeln_var(alias var)() {
    import std.traits;
    writeln(__traits(identifier, var), " = ", var);
}

double[] timings;

image make_mosaic(bool flip)(image im, float scale, int row_count, float blend) {
    import core.simd;
    
    int width  = cast(int) (im.width*scale);
    int height = cast(int) (im.height*scale);
    
    image result = image_init(width, height);
    
    int tile_count = square(row_count);
    
    float s_tile_width  = cast(float)width / row_count;
    float s_tile_height = cast(float)height / row_count;
    
    float4 tile_width  = s_tile_width;
    float4 tile_height = s_tile_height;
    
    float traversal_width  = s_tile_width/scale;
    float traversal_height = s_tile_height/scale;
    
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
    
    v4_lane cubic_hermite(ref v4_lane A, ref v4_lane B, ref v4_lane C, ref v4_lane D, float4 t) {
        // NOTE: https://www.shadertoy.com/view/MllSzX
        float4 one_half = 0.5f;
        float4 two      = 2.0f;
        float4 three    = 3.0f;
        float4 five     = 5.0f;
        
        float4 t2 = t*t;
        float4 t3 = t*t2;
        
        v4_lane half_A = A*one_half;
        v4_lane half_B = B*one_half;
        v4_lane half_C = C*one_half;
        v4_lane half_D = D*one_half;
        
        v4_lane neg_half_A = -half_A;
        
        v4_lane a = neg_half_A + three*half_B - three*half_C + half_D;
        v4_lane b = A - five*half_B + two*C - half_D;
        v4_lane c = neg_half_A + half_C;
        v4_lane d = B;
        
        return a*t3 + b*t2 + c*t + d;
    }
    
    import core.stdc.fenv;
    fesetround(FE_TOWARDZERO);
    
    float4 truncate(float4 x) {
        int4 i = simd!(XMM.CVTPS2DQ)(x);
        return simd!(XMM.CVTDQ2PS)(i);
    }
    
    float4 to_float4(int4 i) {
        return simd!(XMM.CVTDQ2PS)(i);
    }
    
    int4 to_int4(float4 f) {
        return simd!(XMM.CVTPS2DQ)(f);
    }
    
    int4 imwidth  = im.width;
    int4 imheight = im.height;
    
    float4 im_width  = to_float4(imwidth);
    float4 im_height = to_float4(imheight);
    
    int4 one = 1;
    int4 two = 2;
    
    float4 f_zero  = 0.0f;
    float4 f_one   = 1.0f;
    float4 f_three = 3.0f;
    float4 f_255 = 255.0f;
    
    float4 max_width  = im_width - f_three;
    float4 max_height = im_height - f_three;
    
    float4 offsets = [0, 1, 2, 3];
    
    int4 row_count4 = row_count;
    
    auto init_advance = width % 4;
    uint *dest = result.pixels;
    
    import core.time;
    
    foreach (y; 0..height) {
        auto advance = init_advance;
        for (auto x = 0; x < width; ) {
            int4 x4i = x;
            int4 y4i = y;
            
            float4 x4 = to_float4(x4i);
            float4 y4 = to_float4(y4i);
            x4 += offsets;
            
            float4 u = x4 / tile_width;
            float4 v = y4 / tile_height;
            
            int4 blend_x = to_int4(u);
            int4 blend_y = to_int4(v);
            
            u -= truncate(u);
            v -= truncate(v);
            
            static if (flip) {
                float4 flipped_u = f_one - u;
                static foreach(i; 0..4) {
                    if (blend_x.array[i] & 1) {
                        u.array[i] = flipped_u.array[i];
                    }
                }
            }
            
            float4 src_x = u * (im_width);
            float4 src_y = v * (im_height);
            
            clamp(f_one, &src_x, max_width);
            clamp(f_one, &src_y, max_height);
            
            int4 texel_x = to_int4(src_x);
            int4 texel_y = to_int4(src_y);
            
            float4 tx = src_x - truncate(src_x);
            float4 ty = src_y - truncate(src_y);
            
            int4  x0 = texel_x - one;
            alias x1 = texel_x;
            int4  x2 = texel_x + one;
            int4  x3 = texel_x + two;
            
            int4  y0 = texel_y - one;
            alias y1 = texel_y;
            int4  y2 = texel_y + one;
            int4  y3 = texel_y + two;
            
            v4_lane texel00 = im.get_pixel4(x0, y0).rgba4_to_v4_lane;
            v4_lane texel10 = im.get_pixel4(x1, y0).rgba4_to_v4_lane;
            v4_lane texel20 = im.get_pixel4(x2, y0).rgba4_to_v4_lane;
            v4_lane texel30 = im.get_pixel4(x3, y0).rgba4_to_v4_lane;
            
            v4_lane texel01 = im.get_pixel4(x0, y1).rgba4_to_v4_lane;
            v4_lane texel11 = im.get_pixel4(x1, y1).rgba4_to_v4_lane;
            v4_lane texel21 = im.get_pixel4(x2, y1).rgba4_to_v4_lane;
            v4_lane texel31 = im.get_pixel4(x3, y1).rgba4_to_v4_lane;
            
            v4_lane texel02 = im.get_pixel4(x0, y2).rgba4_to_v4_lane;
            v4_lane texel12 = im.get_pixel4(x1, y2).rgba4_to_v4_lane;
            v4_lane texel22 = im.get_pixel4(x2, y2).rgba4_to_v4_lane;
            v4_lane texel32 = im.get_pixel4(x3, y2).rgba4_to_v4_lane;
            
            v4_lane texel03 = im.get_pixel4(x0, y3).rgba4_to_v4_lane;
            v4_lane texel13 = im.get_pixel4(x1, y3).rgba4_to_v4_lane;
            v4_lane texel23 = im.get_pixel4(x2, y3).rgba4_to_v4_lane;
            v4_lane texel33 = im.get_pixel4(x3, y3).rgba4_to_v4_lane;
            
            v4_lane texel0x = cubic_hermite(texel00, texel10, texel20, texel30, tx);
            v4_lane texel1x = cubic_hermite(texel01, texel11, texel21, texel31, tx);
            v4_lane texel2x = cubic_hermite(texel02, texel12, texel22, texel32, tx);
            v4_lane texel3x = cubic_hermite(texel03, texel13, texel23, texel33, tx);
            
            v4_lane output = cubic_hermite(texel0x, texel1x, texel2x, texel3x, ty);
            
            // NOTE: the compiler wouldn't inline this
            clamp(f_zero, &output.r, f_255);
            clamp(f_zero, &output.g, f_255);
            clamp(f_zero, &output.b, f_255);
            clamp(f_zero, &output.a, f_255);
            
            v4_lane big_image_blend;
            int index;
            static foreach(i; 0..4) {
                index = blend_y.array[i]*row_count + blend_x.array[i];
                big_image_blend.r.array[i] = lerp_lut[index].r;
                big_image_blend.g.array[i] = lerp_lut[index].g;
                big_image_blend.b.array[i] = lerp_lut[index].b;
                big_image_blend.a.array[i] = lerp_lut[index].a;
            }
            
            auto output_pixel4 = v4_lane_to_rgba4(lerp(output, blend, big_image_blend));
            
            storeUnaligned(cast(uint4 *)dest, output_pixel4);
            
            dest += advance;
            x += advance;
            advance = 4;
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
    import std.algorithm : mean;
    import core.time;
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
    
    auto start = MonoTime.currTime;
    image mosaic;
    if (cmd.flip) mosaic = make_mosaic!true(im, cmd.scale, cmd.count, cmd.blend);
    else          mosaic = make_mosaic!false(im, cmd.scale, cmd.count, cmd.blend);
    auto end = MonoTime.currTime;
    
    double elapsed = (end - start).total!"msecs" / 1000.0;
    writeln(elapsed, " s");
    writeln("finished. writing out image..."); stdout.flush;
    
    mosaic.write_out_image(output, cmd.jpg_quality);
    writeln("out: ", output);
    
    return EXIT_SUCCESS;
}