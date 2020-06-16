
struct v4 {
    union {
        struct { float x, y, z, w; };
        struct { float r, g, b, a; };
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

v4 lerp(v4 a, float t, v4 b) {
    return (1.0f - t)*a + t*b;
}
