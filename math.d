
T square(T)(T x) {
    return x*x;
}

pragma(inline) float square_root(float x) {
    asm { sqrtss XMM0, x; }
}

T clamp_lower(T)(T x, T min) {
    if (x < min) return  min;
    return x;
}

T clamp_upper(T)(T x, T max) {
    if (x > max) return  max;
    return x;
}

T clamp(T)(T min, T x, T max) {
    return clamp_upper(clamp_lower(x, min), max);
}

T clamp(T)(T min, T *x, T max) {
    return *x = clamp_upper(clamp_lower(*x, min), max);
}

import core.simd;
import vector_math;

float4 clamp(float4 min, float4 *f, float4 max) {
    return *f = simd!(XMM.MINPS)(max, simd!(XMM.MAXPS)(min, *f));
}

v4_lane clamp(float4 min, v4_lane *v, float4 max) {
    clamp(min, &v.r, max);
    clamp(min, &v.g, max);
    clamp(min, &v.b, max);
    clamp(min, &v.a, max);
    return *v;
}
