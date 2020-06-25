
#pragma once

// NOTE: stolen from ginger bill: https://www.gingerbill.org/article/2015/08/19/defer-in-cpp/

#ifndef __cplusplus
#error this only works with C++ :(
#endif

template <typename F>
struct _privDefer {
	F f;
	_privDefer(F f) : f(f) {}
	~_privDefer() { f(); }
};

template <typename F>
_privDefer<F> defer_func(F f) {
	return _privDefer<F>(f);
}

#define DEFER_1(x, y) x##y
#define DEFER_2(x, y) DEFER_1(x, y)
#define DEFER_3(x)    DEFER_2(x, __COUNTER__)
#define Defer(code)   auto DEFER_3(_defer_) = defer_func([&](){code;})