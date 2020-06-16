
import std.conv : to;

T parse_commandline_arguments(T)(string []args) if (is(T == struct)) {
    T result;
    
    for (size_t i = 0; i < args.length; ++i) {
        const arg = args[i];
        
        if (arg[0] == '-') {
            const option = arg[1..$];
            
            string option_argument;
            if (i + 1 < args.length && args[i+1][0] != '-') {
                option_argument = args[++i];
            }
            
            foreach (index, ref field; result.tupleof) {
                if (option == __traits(identifier, result.tupleof[index])) {
                    alias A = typeof(field);
                    
                    if (option_argument.length) {
                        field = to!A(option_argument);
                    } else {
                        static if (is(A == bool)) field = true;
                    }
                    
                    break;
                }
            }
        }
    }
    
    return result;
}

auto parse_commandline_arguments_with_is_set(T)(string []args) if (is(T == struct)) {
    import std.typecons : tuple;
    import std.traits   : FieldNameTuple;
    
    string generate_is_set_type(T)() {
        string result = "struct is_set_type {";
        foreach (name; FieldNameTuple!T) {
            result ~= "bool " ~ name ~ ";";
        }
        result ~= "}";
        return result;
    }
    
    mixin(generate_is_set_type!T);
    
    is_set_type is_set;
    T result;
    
    for (size_t i = 0; i < args.length; ++i) {
        const arg = args[i];
        
        if (arg[0] == '-') {
            const option = arg[1..$];
            
            string option_argument;
            if (i + 1 < args.length && args[i+1][0] != '-') {
                option_argument = args[++i];
            }
            
            foreach (index, ref field; result.tupleof) {
                if (option == __traits(identifier, result.tupleof[index])) {
                    alias A = typeof(field);
                    
                    if (option_argument.length) {
                        field = to!A(option_argument);
                        is_set.tupleof[index] = true;
                    } else {
                        static if (is(A == bool)) {
                            field = true;
                            is_set.tupleof[index] = true;
                        }
                    }
                    
                    break;
                }
            }
        }
    }
    
    return tuple!("options", "is_set")(result, is_set);
}
