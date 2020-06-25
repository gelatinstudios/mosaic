
// NOTE: D doesn't have good support for avx2,
//       so i'm writing this in C++

// TODO: use vpgatherdd for some indexing things

#include <stdio.h>
#include <stdlib.h>
#include <fenv.h>

#include <algorithm>

#include "mosaic_avx.h"

static v4_lane cubic_hermite(v4_lane &A, v4_lane &B, v4_lane &C, v4_lane &D, float8 t) {
    // NOTE: https://www.shadertoy.com/view/MllSzX
    float8 one_half = 0.5f;
    float8 two      = 2.0f;
    float8 three    = 3.0f;
    float8 five     = 5.0f;
    
    float8 t2 = t*t;
    float8 t3 = t*t2;
    
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

extern image make_mosaic_avx2(image im, float scale, int row_count, float blend, bool flip) {
    s32 width  = (s32)(im.width*scale);
    s32 height = (s32)(im.height*scale);
    
    image result = image_init(width, height);
    
    int tile_count = row_count*row_count;
    
    float s_tile_width  = (float)width / row_count;
    float s_tile_height = (float)height / row_count;
    
    float8 tile_width  = s_tile_width;
    float8 tile_height = s_tile_height;
    
    v4 *lerp_lut = (v4 *)alloca(tile_count*sizeof(v4));
    {
        float traversal_width  = s_tile_width/scale;
        float traversal_height = s_tile_height/scale;
        
        int itraversal_width  = (int) traversal_width;
        int itraversal_height = (int) traversal_height;
        
        int pixel_count = itraversal_width * itraversal_height;
        float8 contrib = 8.0f/pixel_count;
        
        int init_advance = itraversal_width % 8;
        
        int8 all_ones = 0xffffffff;
        
        int8 acc_mask;
        for (int i = 0; i < init_advance; ++i) acc_mask.array[i] = 0xffffffff;
        
        int lerp_lut_index = 0;
        for (int iy = 0; iy < row_count; ++iy) {
            for (int ix = 0; ix < row_count; ++ix) {
                int start_x = (int) (ix*traversal_width);
                int start_y = (int) (iy*traversal_height);
                int end_x = start_x + itraversal_width;
                int end_y = start_y + itraversal_height;
                
                u32 *row = im.pixels + im.width*start_y;
                
                v4_lane acc = {};
                for (int y = start_y; y < end_y; ++y) {
                    u32 *pixel = row + start_x;
                    int advance = init_advance;
                    int8 mask = acc_mask;
                    for (int x = start_x; x < end_x; ) {
                        u32 *p = pixel;
                        int8 pixel8;
                        for (int i = 0; i < 8; ++i)
                            pixel8.array[i] = *p++;
                        v4_lane pixels = rgba8_to_v4_lane(pixel8);
                        pixels *= contrib;
                        
                        acc.r += mask & pixels.r;
                        acc.g += mask & pixels.g;
                        acc.b += mask & pixels.b;
                        acc.a += mask & pixels.a;
                        
                        x += advance;
                        pixel += advance;
                        advance = 8;
                        mask = all_ones;
                    }
                    row += im.width;
                }
                
                v4 final_blend = {};
                for (int i = 0; i < 8; ++i) {
                    final_blend.r += acc.r.array[i]*0.125f;
                    final_blend.g += acc.g.array[i]*0.125f;
                    final_blend.b += acc.b.array[i]*0.125f;
                    final_blend.a += acc.a.array[i]*0.125f;
                }
                
                lerp_lut[lerp_lut_index++] = final_blend;
            }
        }
    }
    
    float8 im_width  = (float) im.width;
    float8 im_height = (float) im.height;
    
    int8 one = 1;
    int8 two = 2;
    
    float8 f_zero  = 0.0f;
    float8 f_one   = 1.0f;
    float8 f_three = 3.0f;
    float8 f_255 = 255.0f;
    
    float8 max_width  = im_width - f_three;
    float8 max_height = im_height - f_three;
    
    float8 offsets(0, 1, 2, 3, 4, 5, 6, 7);
    
    int8 row_count4 = row_count;
    
    auto init_advance = width % 8;
    u32 *dest = result.pixels;
    
    fesetround(FE_TOWARDZERO);
    
    if (flip) {
        for (int y = 0; y < height; ++y) {
            auto advance = init_advance;
            for (int x = 0; x < width; ) {
                float8 x8 = (float)x;
                float8 y8 = (float)y;
                x8 += offsets;
                
                float8 u = x8 / tile_width;
                float8 v = y8 / tile_height;
                
                int8 blend_x = to_int8(u);
                int8 blend_y = to_int8(v);
                
                u -= floor(u);
                v -= floor(v);
                
                float8 flipped_u = f_one - u;
                for (int i = 0; i < 8; ++i) {
                    if (blend_x.array[i] & 1) {
                        u.array[i] = flipped_u.array[i];
                    }
                }
                
                float8 src_x = u * (im_width);
                float8 src_y = v * (im_height);
                
                clamp(f_one, &src_x, max_width);
                clamp(f_one, &src_y, max_height);
                
                int8 texel_x = to_int8(src_x);
                int8 texel_y = to_int8(src_y);
                
                float8 tx = src_x - floor(src_x);
                float8 ty = src_y - floor(src_y);
                
                int8 x0 = texel_x - one;
                int8 x1 = texel_x;
                int8 x2 = texel_x + one;
                int8 x3 = texel_x + two;
                
                int8 y0 = texel_y - one;
                int8 y1 = texel_y;
                int8 y2 = texel_y + one;
                int8 y3 = texel_y + two;
                
                v4_lane texel00 = rgba8_to_v4_lane(im.get_pixel8(x0, y0));
                v4_lane texel10 = rgba8_to_v4_lane(im.get_pixel8(x1, y0));
                v4_lane texel20 = rgba8_to_v4_lane(im.get_pixel8(x2, y0));
                v4_lane texel30 = rgba8_to_v4_lane(im.get_pixel8(x3, y0));
                
                v4_lane texel01 = rgba8_to_v4_lane(im.get_pixel8(x0, y1));
                v4_lane texel11 = rgba8_to_v4_lane(im.get_pixel8(x1, y1));
                v4_lane texel21 = rgba8_to_v4_lane(im.get_pixel8(x2, y1));
                v4_lane texel31 = rgba8_to_v4_lane(im.get_pixel8(x3, y1));
                
                v4_lane texel02 = rgba8_to_v4_lane(im.get_pixel8(x0, y2));
                v4_lane texel12 = rgba8_to_v4_lane(im.get_pixel8(x1, y2));
                v4_lane texel22 = rgba8_to_v4_lane(im.get_pixel8(x2, y2));
                v4_lane texel32 = rgba8_to_v4_lane(im.get_pixel8(x3, y2));
                
                v4_lane texel03 = rgba8_to_v4_lane(im.get_pixel8(x0, y3));
                v4_lane texel13 = rgba8_to_v4_lane(im.get_pixel8(x1, y3));
                v4_lane texel23 = rgba8_to_v4_lane(im.get_pixel8(x2, y3));
                v4_lane texel33 = rgba8_to_v4_lane(im.get_pixel8(x3, y3));
                
                v4_lane texel0x = cubic_hermite(texel00, texel10, texel20, texel30, tx);
                v4_lane texel1x = cubic_hermite(texel01, texel11, texel21, texel31, tx);
                v4_lane texel2x = cubic_hermite(texel02, texel12, texel22, texel32, tx);
                v4_lane texel3x = cubic_hermite(texel03, texel13, texel23, texel33, tx);
                
                v4_lane output = cubic_hermite(texel0x, texel1x, texel2x, texel3x, ty);
                
                clamp(f_zero, &output.r, f_255);
                clamp(f_zero, &output.g, f_255);
                clamp(f_zero, &output.b, f_255);
                clamp(f_zero, &output.a, f_255);
                
                v4_lane big_image_blend = {};
                for (int i = 0; i < 8; ++i) {
                    int index = blend_y.array[i]*row_count + blend_x.array[i];
                    big_image_blend.r.array[i] = lerp_lut[index].r;
                    big_image_blend.g.array[i] = lerp_lut[index].g;
                    big_image_blend.b.array[i] = lerp_lut[index].b;
                    big_image_blend.a.array[i] = lerp_lut[index].a;
                }
                
                auto output_pixel8 = v4_lane_to_rgba8(lerp(output, blend, big_image_blend));
                
                _mm256_storeu_si256((__m256i *)dest, output_pixel8.v);
                
                dest += advance;
                x += advance;
                advance = 8;
            }
        }
    } else {
        for (int y = 0; y < height; ++y) {
            auto advance = init_advance;
            for (int x = 0; x < width; ) {
                float8 x8 = (float)x;
                float8 y8 = (float)y;
                x8 += offsets;
                
                float8 u = x8 / tile_width;
                float8 v = y8 / tile_height;
                
                int8 blend_x = to_int8(u);
                int8 blend_y = to_int8(v);
                
                u -= floor(u);
                v -= floor(v);
                
                float8 src_x = u * (im_width);
                float8 src_y = v * (im_height);
                
                clamp(f_one, &src_x, max_width);
                clamp(f_one, &src_y, max_height);
                
                int8 texel_x = to_int8(src_x);
                int8 texel_y = to_int8(src_y);
                
                float8 tx = src_x - floor(src_x);
                float8 ty = src_y - floor(src_y);
                
                int8 x0 = texel_x - one;
                int8 x1 = texel_x;
                int8 x2 = texel_x + one;
                int8 x3 = texel_x + two;
                
                int8 y0 = texel_y - one;
                int8 y1 = texel_y;
                int8 y2 = texel_y + one;
                int8 y3 = texel_y + two;
                
                v4_lane texel00 = rgba8_to_v4_lane(im.get_pixel8(x0, y0));
                v4_lane texel10 = rgba8_to_v4_lane(im.get_pixel8(x1, y0));
                v4_lane texel20 = rgba8_to_v4_lane(im.get_pixel8(x2, y0));
                v4_lane texel30 = rgba8_to_v4_lane(im.get_pixel8(x3, y0));
                
                v4_lane texel01 = rgba8_to_v4_lane(im.get_pixel8(x0, y1));
                v4_lane texel11 = rgba8_to_v4_lane(im.get_pixel8(x1, y1));
                v4_lane texel21 = rgba8_to_v4_lane(im.get_pixel8(x2, y1));
                v4_lane texel31 = rgba8_to_v4_lane(im.get_pixel8(x3, y1));
                
                v4_lane texel02 = rgba8_to_v4_lane(im.get_pixel8(x0, y2));
                v4_lane texel12 = rgba8_to_v4_lane(im.get_pixel8(x1, y2));
                v4_lane texel22 = rgba8_to_v4_lane(im.get_pixel8(x2, y2));
                v4_lane texel32 = rgba8_to_v4_lane(im.get_pixel8(x3, y2));
                
                v4_lane texel03 = rgba8_to_v4_lane(im.get_pixel8(x0, y3));
                v4_lane texel13 = rgba8_to_v4_lane(im.get_pixel8(x1, y3));
                v4_lane texel23 = rgba8_to_v4_lane(im.get_pixel8(x2, y3));
                v4_lane texel33 = rgba8_to_v4_lane(im.get_pixel8(x3, y3));
                
                v4_lane texel0x = cubic_hermite(texel00, texel10, texel20, texel30, tx);
                v4_lane texel1x = cubic_hermite(texel01, texel11, texel21, texel31, tx);
                v4_lane texel2x = cubic_hermite(texel02, texel12, texel22, texel32, tx);
                v4_lane texel3x = cubic_hermite(texel03, texel13, texel23, texel33, tx);
                
                v4_lane output = cubic_hermite(texel0x, texel1x, texel2x, texel3x, ty);
                
                clamp(f_zero, &output.r, f_255);
                clamp(f_zero, &output.g, f_255);
                clamp(f_zero, &output.b, f_255);
                clamp(f_zero, &output.a, f_255);
                
                v4_lane big_image_blend = {};
                for (int i = 0; i < 8; ++i) {
                    int index = blend_y.array[i]*row_count + blend_x.array[i];
                    big_image_blend.r.array[i] = lerp_lut[index].r;
                    big_image_blend.g.array[i] = lerp_lut[index].g;
                    big_image_blend.b.array[i] = lerp_lut[index].b;
                    big_image_blend.a.array[i] = lerp_lut[index].a;
                }
                
                auto output_pixel8 = v4_lane_to_rgba8(lerp(output, blend, big_image_blend));
                
                _mm256_storeu_si256((__m256i *)dest, output_pixel8.v);
                
                dest += advance;
                x += advance;
                advance = 8;
            }
        }
    }
    
    return result;
}
