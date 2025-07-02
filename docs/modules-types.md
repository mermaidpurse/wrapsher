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
io = _as_moduleio(module/io, 'opaque value')
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

When you do `type vector list`, conceptually this happens:

```
type type/vector something

vector = _from_string(type/vector, 'opaque value')

vector _as_vector(list l) {
  ...
}

list _as_list(vector v) {
  ...
}
```

You should (must?) also implement a `new` function to create a
zero-value instance of the new type, and should create guarded
casts if applicable.

