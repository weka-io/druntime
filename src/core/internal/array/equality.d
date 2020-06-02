/**
 * This module contains compiler support determining equality of arrays.
 *
 * Copyright: Copyright Digital Mars 2000 - 2020.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Source: $(DRUNTIMESRC core/internal/_array/_equality.d)
 */

module core.internal.array.equality;

// compiler frontend lowers dynamic array comparison to this
bool __ArrayEq(T1, T2)(T1[] a, T2[] b)
{
    if (a.length != b.length)
        return false;
    foreach (size_t i; 0 .. a.length)
    {
        if (a[i] != b[i])
            return false;
    }
    return true;
}

// The compiler lowers `lhs == rhs` to `__equals(lhs, rhs)` for
// * dynamic arrays,
// * (most) arrays of different (unqualified) element types, and
// * arrays of structs with custom opEquals.
bool __equals(T1, T2)(scope T1[] lhs, scope T2[] rhs)
{
    if (lhs.length != rhs.length)
        return false;

    if (lhs.length == 0)
        return true;

    static if (useMemcmp!(T1, T2))
    {
        if (!__ctfe)
        {
            static bool trustedMemcmp(scope T1[] lhs, scope T2[] rhs) @trusted @nogc nothrow pure
            {
                pragma(inline, true);
                import core.stdc.string : memcmp;
                return memcmp(cast(void*) lhs.ptr, cast(void*) rhs.ptr, lhs.length * T1.sizeof) == 0;
            }
            return trustedMemcmp(lhs, rhs);
        }
        else
        {
            foreach (const i; 0 .. lhs.length)
            {
                if (at(lhs, i) != at(rhs, i))
                    return false;
            }
            return true;
        }
    }
    else
    {
        foreach (const i; 0 .. lhs.length)
        {
            if (at(lhs, i) != at(rhs, i))
                return false;
        }
        return true;
    }
}

@safe unittest
{
    assert(__equals([], []));
    assert(!__equals([1, 2], [1, 2, 3]));
}

@safe unittest
{
    auto a = "hello"c;

    assert(a != "hel");
    assert(a != "helloo");
    assert(a != "betty");
    assert(a == "hello");
    assert(a != "hxxxx");

    float[] fa = [float.nan];
    assert(fa != fa);
}

@safe unittest
{
    struct A
    {
        int a;
    }

    auto arr1 = [A(0), A(2)];
    auto arr2 = [A(0), A(1)];
    auto arr3 = [A(0), A(1)];

    assert(arr1 != arr2);
    assert(arr2 == arr3);
}

@safe unittest
{
    struct A
    {
        int a;
        int b;

        bool opEquals(const A other)
        {
            return this.a == other.b && this.b == other.a;
        }
    }

    auto arr1 = [A(1, 0), A(0, 1)];
    auto arr2 = [A(1, 0), A(0, 1)];
    auto arr3 = [A(0, 1), A(1, 0)];

    assert(arr1 != arr2);
    assert(arr2 == arr3);
}

// https://issues.dlang.org/show_bug.cgi?id=18252
@safe unittest
{
    string[int][] a1, a2;
    assert(__equals(a1, a2));
    assert(a1 == a2);
    a1 ~= [0: "zero"];
    a2 ~= [0: "zero"];
    assert(__equals(a1, a2));
    assert(a1 == a2);
    a2[0][1] = "one";
    assert(!__equals(a1, a2));
    assert(a1 != a2);
}


private:

// - Recursively folds static array types to their element type,
// - maps void to ubyte, and
// - pointers to size_t.
template BaseType(T)
{
    static if (__traits(isStaticArray, T))
        alias BaseType = BaseType!(typeof(T.init[0]));
    else static if (is(immutable T == immutable void))
        alias BaseType = ubyte;
    else static if (is(T == E*, E))
        alias BaseType = size_t;
    else
        alias BaseType = T;
}

// Use memcmp if the element sizes match and both base element types are integral.
// Due to int promotion, disallow small integers of diverging signed-ness though.
template useMemcmp(T1, T2)
{
    static if (T1.sizeof != T2.sizeof)
        enum useMemcmp = false;
    else
    {
        alias B1 = BaseType!T1;
        alias B2 = BaseType!T2;
        enum useMemcmp = __traits(isIntegral, B1) && __traits(isIntegral, B2)
           && !( (B1.sizeof < 4 || B2.sizeof < 4) && __traits(isUnsigned, B1) != __traits(isUnsigned, B2) );
    }
}

unittest
{
    enum E { foo, bar }

    static assert(useMemcmp!(byte, byte));
    static assert(useMemcmp!(ubyte, ubyte));
    static assert(useMemcmp!(void, const void));
    static assert(useMemcmp!(void, immutable bool));
    static assert(useMemcmp!(void, inout char));
    static assert(useMemcmp!(void, shared ubyte));
    static assert(!useMemcmp!(void, byte));       // differing signed-ness
    static assert(!useMemcmp!(char[8], byte[8])); // ditto

    static assert(useMemcmp!(short, short));
    static assert(useMemcmp!(wchar, ushort));
    static assert(!useMemcmp!(wchar, short)); // differing signed-ness

    static assert(useMemcmp!(int, uint)); // no promotion, ignoring signed-ness
    static assert(useMemcmp!(dchar, E));

    static assert(useMemcmp!(immutable void*, size_t));
    static assert(useMemcmp!(double*, ptrdiff_t));
    static assert(useMemcmp!(long[2][3], const(ulong)[2][3]));

    static assert(!useMemcmp!(float, float));
    static assert(!useMemcmp!(double[2], double[2]));
    static assert(!useMemcmp!(Object, Object));
    static assert(!useMemcmp!(int[], int[]));
}

// Returns a reference to an array element, eliding bounds check and
// casting void to ubyte.
pragma(inline, true)
ref at(T)(T[] r, size_t i) @trusted
    // exclude opaque structs due to https://issues.dlang.org/show_bug.cgi?id=20959
    if (!(is(T == struct) && !is(typeof(T.sizeof))))
{
    static if (is(immutable T == immutable void))
        return (cast(ubyte*) r.ptr)[i];
    else
        return r.ptr[i];
}
