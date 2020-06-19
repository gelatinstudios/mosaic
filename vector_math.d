
struct v4 {
    union {
        struct { float x, y, z, w; };
        struct { float r, g, b, a; };
    }
    
    v4 opUnary(string op)() if (op == "-") {
        return v4(-x, -y, -z, -w);
    }
    
    v4 opBinary(string op)(v4 l) if (op == "+" || op == "-") {
        mixin("return v4(x" ~ op ~ "l.x, y" ~ op ~ "l.y, z" ~ op ~ "l.z, w" ~ op ~ "l.w);");
    }
    
    v4 opBinary(string op)(float f) if (op == "*") {
        return v4(f*x, f*y, f*z, f*w);
    }
    
    v4 opBinaryRight(string op)(float f) if (op == "*") {
        return opBinary!op(f);
    }
    
    v4 opOpAssign(string op,T)(T l) {
        return this = this.opBinary!op(l);
    }
    
    string toString() {
        import std.conv : to;
        return "v4("~x.to!string~", "~y.to!string~", "~z.to!string~", "~w.to!string~")";
    }
}

void clamp(T)(float min, T *v, float max) if (is(T == v4)) {
    import math : clamp;
    clamp(min, &v.x, max);
    clamp(min, &v.y, max);
    clamp(min, &v.z, max);
    clamp(min, &v.w, max);
}

v4 lerp(v4 a, float t, v4 b) {
    return (1.0f - t)*a + t*b;
}

import core.simd;

struct v4_lane {
    union {
        struct { float4 x, y, z, w; };
        struct { float4 r, g, b, a; };
    }
    
    v4_lane opUnary(string op)() if (op == "-") {
        return v4_lane(-x, -y, -z, -w);
    }
    
    v4_lane opBinary(string op)(v4_lane l) if (op == "+" || op == "-") {
        mixin("return v4_lane(x" ~ op ~ "l.x, y" ~ op ~ "l.y, z" ~ op ~ "l.z, w" ~ op ~ "l.w);");
    }
    
    v4_lane opBinary(string op)(float4 f) if (op == "*") {
        return v4_lane(f*x, f*y, f*z, f*w);
    }
    
    v4_lane opBinaryRight(string op)(float4 f) if (op == "*") {
        return opBinary!op(f);
    }
    
    v4_lane opOpAssign(string op,T)(T l) {
        return this = this.opBinary!op(l);
    }
    
    string toString() {
        import std.conv : to;
        return "v4_lane("~x.to!string~", "~y.to!string~", "~z.to!string~", "~w.to!string~")";
    }
}

T lerp(T)(T a, float t, T b) {
    return (1.0f - t)*a + t*b;
}

v4_lane lerp(ref v4_lane a, float4 t, ref v4_lane b) {
    return (1.0f - t)*a + t*b;
}
