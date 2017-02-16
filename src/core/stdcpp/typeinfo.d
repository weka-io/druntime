// Written in the D programming language.

/**
 * Interface to C++ <typeinfo>
 *
 * Copyright: Copyright (c) 2016 D Language Foundation
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(DRUNTIMESRC core/stdcpp/_typeinfo.d)
 */

module core.stdcpp.typeinfo;

version (CRuntime_DigitalMars)
{
    import core.stdcpp.exception;

    extern (C++, std)
    {
        class type_info
        {
            void* pdata;

          public:
            //virtual ~this();
            void dtor() { }     // reserve slot in vtbl[]

            //bool operator==(const type_info rhs) const;
            //bool operator!=(const type_info rhs) const;
            final bool before(const type_info rhs) const;
            final const(char)* name() const;
          protected:
            //type_info();
          private:
            //this(const type_info rhs);
            //type_info operator=(const type_info rhs);
        }

        class bad_cast : core.stdcpp.exception.std.exception
        {
            this() nothrow { }
            this(const bad_cast) nothrow { }
            //bad_cast operator=(const bad_cast) nothrow { return this; }
            //virtual ~this() nothrow;
            override const(char)* what() const nothrow;
        }

        class bad_typeid : core.stdcpp.exception.std.exception
        {
            this() nothrow { }
            this(const bad_typeid) nothrow { }
            //bad_typeid operator=(const bad_typeid) nothrow { return this; }
            //virtual ~this() nothrow;
            override const (char)* what() const nothrow;
        }
    }
}
else version (CRuntime_Microsoft)
{
    import core.stdcpp.exception;

    struct __type_info_node
    {
        void* _MemPtr;
        __type_info_node* _Next;
    }

    extern __gshared __type_info_node __type_info_root_node;

    extern (C++, std)
    {
        class type_info
        {

          public:
            //virtual ~this();
            void dtor() { }     // reserve slot in vtbl[]
            //bool operator==(const type_info rhs) const;
            //bool operator!=(const type_info rhs) const;
            final bool before(const type_info rhs) const;
            final const(char)* name(__type_info_node* p = &__type_info_root_node) const;

          private:
            void* pdata;
            char[1] _name;
            //this(const type_info rhs);
            //type_info operator=(const type_info rhs);
        }

        class bad_cast : core.stdcpp.exception.std.exception
        {
            this(const(char)* msg = "bad cast") { }
            this(const bad_cast) { }
            //virtual ~this();
        }

        class bad_typeid : core.stdcpp.exception.std.exception
        {
            this(const(char)* msg = "bad typeid") { }
            this(const bad_typeid) { }
            //virtual ~this();
        }
    }
}
else version (CRuntime_Glibc)
{
    import core.stdcpp.exception;

    extern (C++, __cxxabiv1)
    {
        class __class_type_info;
    }

    extern (C++, std)
    {
        class type_info
        {
            void dtor1();                           // consume destructor slot in vtbl[]
            void dtor2();                           // consume destructor slot in vtbl[]
            final const(char)* name();
            final bool before(const type_info) const;
            //bool operator==(const type_info) const;
            bool __is_pointer_p() const;
            bool __is_function_p() const;
            bool __do_catch(const type_info, void**, uint) const;
            bool __do_upcast(const __cxxabiv1.__class_type_info, void**) const;

            const(char)* _name;
            this(const(char)*);
        }

        class bad_cast : core.stdcpp.exception.std.exception
        {
            this();
            //~this();
            override const(char)* what() const;
        }

        class bad_typeid : core.stdcpp.exception.std.exception
        {
            this();
            //~this();
            override const(char)* what() const;
        }
    }
}
