module core.internal.lifetime;

import core.lifetime : forward;

/+
emplaceRef is a package function for druntime internal use. It works like
emplace, but takes its argument by ref (as opposed to "by pointer").
This makes it easier to use, easier to be safe, and faster in a non-inline
build.
Furthermore, emplaceRef optionally takes a type parameter, which specifies
the type we want to build. This helps to build qualified objects on mutable
buffer, without breaking the type system with unsafe casts.
+/
void emplaceRef(T, UT, Args...)(ref UT chunk, auto ref Args args)
{
    static if (args.length == 0)
    {
        static assert(is(typeof({static T i;})),
            "Cannot emplace a " ~ T.stringof ~ " because " ~ T.stringof ~
            ".this() is annotated with @disable.");
        static if (is(T == class)) static assert(!__traits(isAbstractClass, T),
            T.stringof ~ " is abstract and it can't be emplaced");
        emplaceInitializer(chunk);
    }
    else static if (
        !is(T == struct) && Args.length == 1 /* primitives, enums, arrays */
        ||
        Args.length == 1 && is(typeof({T t = forward!(args[0]);})) /* conversions */
        ||
        is(typeof(T(forward!args))) /* general constructors */)
    {
        static struct S
        {
            T payload;
            this()(auto ref Args args)
            {
                static if (is(typeof(payload = forward!args)))
                    payload = forward!args;
                else
                    payload = T(forward!args);
            }
        }
        if (__ctfe)
        {
            static if (is(typeof(chunk = T(forward!args))))
                chunk = T(forward!args);
            else static if (args.length == 1 && is(typeof(chunk = forward!(args[0]))))
                chunk = forward!(args[0]);
            else assert(0, "CTFE emplace doesn't support "
                ~ T.stringof ~ " from " ~ Args.stringof);
        }
        else
        {
            S* p = () @trusted { return cast(S*) &chunk; }();
            static if (UT.sizeof > 0)
                emplaceInitializer(*p);
            p.__ctor(forward!args);
        }
    }
    else static if (is(typeof(chunk.__ctor(forward!args))))
    {
        // This catches the rare case of local types that keep a frame pointer
        emplaceInitializer(chunk);
        chunk.__ctor(forward!args);
    }
    else
    {
        //We can't emplace. Try to diagnose a disabled postblit.
        static assert(!(Args.length == 1 && is(Args[0] : T)),
            "Cannot emplace a " ~ T.stringof ~ " because " ~ T.stringof ~
            ".this(this) is annotated with @disable.");

        //We can't emplace.
        static assert(false,
            T.stringof ~ " cannot be emplaced from " ~ Args[].stringof ~ ".");
    }
}

// ditto
static import core.internal.traits;
void emplaceRef(UT, Args...)(ref UT chunk, auto ref Args args)
if (is(UT == core.internal.traits.Unqual!UT))
{
    emplaceRef!(UT, UT)(chunk, forward!args);
}

/+
Emplaces T.init.
In contrast to `emplaceRef(chunk)`, there are no checks for disabled default
constructors etc.
+/
void emplaceInitializer(T)(scope ref T chunk) nothrow pure @trusted
    if (!is(T == const) && !is(T == immutable) && !is(T == inout))
{
    import core.internal.traits : hasElaborateAssign;

    static if (!hasElaborateAssign!T && __traits(compiles, chunk = T.init))
    {
        chunk = T.init;
    }
    else static if (__traits(isZeroInit, T))
    {
        static if (is(T U == shared U))
            alias Unshared = U;
        else
            alias Unshared = T;

        import core.stdc.string : memset;
        memset(cast(Unshared*) &chunk, 0, T.sizeof);
    }
    else
    {
        // emplace T.init (an rvalue) without extra variable (and according destruction)
        alias RawBytes = void[T.sizeof];

        static union U
        {
            T dummy = T.init; // U.init corresponds to T.init
            RawBytes data;
        }

        *cast(RawBytes*) &chunk = U.init.data;
    }
}

@safe unittest
{
    static void testInitializer(T)()
    {
        // mutable T
        {
            T dst = void;
            emplaceInitializer(dst);
            assert(dst is T.init);
        }

        // shared T
        {
            shared T dst = void;
            emplaceInitializer(dst);
            assert(dst is shared(T).init);
        }

        // const T
        {
            const T dst = void;
            static assert(!__traits(compiles, emplaceInitializer(dst)));
        }
    }

    static struct ElaborateAndZero
    {
        int a;
        this(this) {}
    }

    static struct ElaborateAndNonZero
    {
        int a = 42;
        this(this) {}
    }

    testInitializer!int();
    testInitializer!double();
    testInitializer!ElaborateAndZero();
    testInitializer!ElaborateAndNonZero();
}
