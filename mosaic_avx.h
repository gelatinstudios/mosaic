#ifndef MOSAIC_AVX_H
#define MOSAIC_AVX_H

#include <xmmintrin.h>
#include <immintrin.h>

#include "jt_int.h"

struct float8 {
    union {
        __m256 v;
        float array[8];
    };
    
    float8() { v = {}; }
    float8(__m256 m) { v = m; }
    float8(float f) { v = _mm256_set1_ps(f); }
    float8(float f0, float f1, float f2, float f3, float f4, float f5, float f6, float f7) {
        v = _mm256_set_ps(f7, f6, f5, f4, f3, f2, f1, f0);
    }
    
    float8 operator - (float8 f) { return float8(_mm256_sub_ps(v, f.v)); }
    float8 operator + (float8 f) { return float8(_mm256_add_ps(v, f.v)); }
    float8 operator * (float8 f) { return float8(_mm256_mul_ps(v, f.v)); }
    float8 operator / (float8 f) { return float8(_mm256_div_ps(v, f.v)); }
    float8 operator - () { return float8(0.0f) - *this; }
    float8 operator += (float8 f) { return *this = *this + f; }
    float8 operator -= (float8 f) { return *this = *this - f; }
    float8 operator *= (float8 f) { return *this = *this * f; }
    float8 operator /= (float8 f) { return *this = *this / f; }
};

struct int8 {
    union {
        __m256i v;
        s32 array[8];
    };
    
    int8() { v = {}; }
    int8(__m256i m) { v = m; }
    int8(s32 i) { v = _mm256_set1_epi32(i); }
    int8(u32 i) { v = _mm256_set1_epi32(i); }
    
    float8 operator & (float8 f) { return float8(_mm256_and_ps(*(__m256 *)&v, f.v)); }
    
    int8 operator + (int8 f) { return int8(_mm256_add_epi32(v, f.v)); }
    int8 operator - (int8 f) { return int8(_mm256_sub_epi32(v, f.v)); }
};

static int8 to_int8(float8 f) {
    return int8(_mm256_cvtps_epi32(f.v));
}

static float8 floor(float8 f) {
    return float8(_mm256_floor_ps(f.v));
}

static void clamp(float8 min, float8 *x, float8 max) {
    x->v = _mm256_max_ps(_mm256_min_ps(x->v, max.v), min.v);
}

struct v4 {
    union {
        struct { float x, y, z, w; };
        struct { float r, g, b, a; };
    };
};

struct v4_lane {
    union {
        struct { float8 x, y, z, w; };
        struct { float8 r, g, b, a; };
    };
    
    v4_lane operator - () {
        return { -x, -y, -z, -w };
    }
    v4_lane operator + (v4_lane v) {
        return {
            v.x + x,
            v.y + y,
            v.z + z,
            v.w + w,
        };
    }
    v4_lane operator - (v4_lane v) {
        return {
            x - v.x,
            y - v.y,
            z - v.z,
            w - v.w,
        };
    }
    v4_lane operator * (float8 f) {
        return { f*x, f*y, f*z, f*w };
    }
    
    v4_lane operator *= (float8 f) {
        return *this = *this * f;
    }
};
v4_lane operator * (float8 f, v4_lane v) {
    return v*f;
}

static v4_lane rgba8_to_v4_lane(int8 p) {
    v4_lane result = {};
    for (int i = 0; i < 8; ++i) {
        result.r.array[i] = (p.array[i] >> 0)  & 0xff;
        result.g.array[i] = (p.array[i] >> 8)  & 0xff;
        result.b.array[i] = (p.array[i] >> 16) & 0xff;
        result.a.array[i] = (p.array[i] >> 24) & 0xff;
    }
    return result;
}

static int8 v4_lane_to_rgba8(v4_lane &v) {
    int8 result = {};
    for (int i = 0; i < 8; ++i) {
        result.array[i] |= (u8)(v.r.array[i] + 0.5f) << 0;
        result.array[i] |= (u8)(v.g.array[i] + 0.5f) << 8;
        result.array[i] |= (u8)(v.b.array[i] + 0.5f) << 16;
        result.array[i] |= (u8)(v.a.array[i] + 0.5f) << 24;
    }
    return result;
}

struct image {
    s32 width;
    s32 height;
    u32 *pixels;
    
    u32 get_pixel(int x, int y) {
        return *(pixels + width*y + x);
    }
    
    int8 get_pixel8(int8 x, int8 y) {
        int8 result = {};
        for (int i = 0; i < 8; ++i) {
            result.array[i] = get_pixel(x.array[i], y.array[i]);
        }
        return result;
    }
};

static image image_init(s32 width, s32 height) {
    image result = {};
    result.width  = width;
    result.height = height;
    result.pixels = (u32 *)malloc(sizeof(u32)*width*height);
    return result;
}

static v4_lane lerp(v4_lane &a, float8 t, v4_lane &b) {
    return (float8(1.0f) - t)*a + t*b;
}

#endif //MOSAIC_AVX_H
