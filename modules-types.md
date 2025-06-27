# Modules and Types

Wrapsher offers modules for code organization, and types.

Function arguments and return values are checked for types. In
Wrapsher, values have types, not variables (though it would be
nice to have at least some compile-type type checking, this is
not the way type checking and function dispatch works right now).

## Implementation of Modules

When you `use module mymodule`, the compiler finds the
module to include from its include path and includes it in the program.

Wrapsher doesn't have separate function namespaces, which means
a module can define a function for any type, in any namespace. By
convention, a module usually restricts itself to functions
with receivers of its own module type or types that it creates
using `type`.

When you do `module io`, a global variable `io` is created that
is bound to a value of type `module/io`, which is why you can
then implement module-level functions like this:

```
int println(module/io m, string s)
```

Conceptually, something similar to this happens:
```
type module/io string

io = _from_string(module/io, 'opaque value')
```

## Implementation of Types

Types always "wrap" another type, so when you do `type <newtype>
<othertype>`, you're essentially saying that you are going to use
`<othertype>` to store sufficient information about your type
instance. If this smells a little like Perl-style blessed values
as type storage, that's the right mental model.

The `type` statement automatically creates converters to convert
to and from the underlying type. These are "unsafe" in the sense
that they are unguarded, but they remain typesafe (they aren't
dangerous casts in the typical sense).

A type variable with the type type is also created, so that you
can write and call functions that operate on the type itself,
such as constructors.

There is no such thing as nullity in Wrapsher: all types have a
zero-value. You will need to use other mechanisms for optional
values.

When you do `type vector array`, conceptually this happens:

```
type type/vector string

vector = _from_string(type/vector, 'opaque value')

vector _as_vector(array a) {
  ...
}

array _as_array(vector v) {
  ...
}
```

You should (must?) also implement a `new` function to create a
zero-value instance of the new type, and should create guarded
converters if applicable.

## Internal type implementations

Since Wrapsher is running in a POSIX shell, it uses a simple
tagged value scheme for tracking type information. Each value
is tagged like this:

`<type>:<shtringvalue>`

Since only strings are available, it means that something more
complicated is required for collection types `map` and `array`.

These are actually reference-based, but the reference mechanism
is internal to Wrapsher and will probably not be exposed. References
are cleaned up when the collections are modified. Internally,
a three-member array of strings looks something like this:

`array:ref:1000 ref:1001 ref:1002`

When you access an array member, it is dereferenced (it's a reference
to a shell variable out there named something like `_wshr_1001`.

References are never shared; this is not subject to garbage collection
problems. This is only a mechanism to ease handling of data that has
to occur in shell strings.

When a type is wrapped by declaring a new type, it gets prepended
to the value. So after we've created our vector, it'll internally
look something like:

`vector:array:ref:1000 ref:1001 ref:1002`

All `_as_vector(a)` really does is strip the `vector` part,
exposing the underlying array.
