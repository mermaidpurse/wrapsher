# Modules and Types

Wrapsher offers modules for code organization; and types,
to define methods.

Function arguments and return values are checked for types. In
Wrapsher, values have types, not variables (though it would be
nice to have at least some compile-type type checking, this is
not the way type checking and function dispatch works right now).

## Implementation of Modules

When you `use module mymodule`, the compiler finds the module to
include from its include path and includes it in the program. By default,
the include path is `$WSH_HOME/wsh:wsh`; it can be added to by
setting the `WSH_INCLUDE` environment variable or passing directories
with `-I` to the compiler.

Wrapsher doesn't have separate function namespaces, which means
a module can define a function for any type, in any namespace. By
convention, a module usually restricts itself to functions
with receivers of its own module type or types that it creates
using `type`.[^2]

[^2]: Probably violating this "convention" will eventually become
  a compiler error or lint.

When you do `module io`, a global variable `io` is created that
is bound to a value of type `module/io`, which is why you can
then implement module-level functions like this:

```wrapsher
int println(module/io m, string s)
```

Since `io` is a global variable with type `module/io`, you can
call `println` on it:

```wrapsher
io.println('my cool string')
```

## Implementation of Types

Types always "wrap" another type, so when you do <code>type
_newtype_ _othertype_</code>, you're essentially saying that
you are going to use _othertype_ to store all the data in
your type instance. If this smells a little like Perl-style blessed
values as type storage, that's the right mental model.

The `any _as(any, any)` function converts a value from a storage type
into any type that wraps it; or a value into its storage type.

A type variable with the type type is also created, so that you
can write and call functions that operate on the type itself,
such as constructors. This is an implementation detail that allows
you to refer to the type by name. It's similar to modules, where
the global variable `mycooltype` is of type `type/mycooltype`.

When you create a type with a map instead of a storage type, it creates
a struct implemented internally as a list. The map defines the member
names and types; these are used to provide getters and setters and
other functions to implement the struct.

## Optionals, nulls, zero values and exceptions

There is no such thing as nullity in Wrapsher: all types have a
zero-value, as in Go, and all variables are initialized. You will need
to use other mechanisms for optional values.

It's important to Wrapsher's philosophy that while you can fail,
you should not be acting on a wrong answer. So the following are
all discouraged:

- In-band signalling of missing values, wrong values or errors
  (e.g. returning -1 to mean "not found"); though some functions like
  `get()` may offer a way to get a default value.
- Using errors for flow control, i.e. try/catch to deal with errors
  like files not existing, elements not existing in a collection, or
  subscripts out of bounds. Wrapsher doesn't have typed, structured
  errors, and discourages the use of them as flow-control
  exceptions. The ability to catch errors is so that you can make
  things cleaner and safer before stopping; not to continue down an
  alternate path.
- Use of complex return values that have to be checked for
  optionality. Since Wrapsher has a simple type system, is not
  object-oriented and has only one kind of generic (`any`), it's not
  really easy to create record types that flag optionality or failure
  "next to" a function return value (certainly not efficiently).
  Similarly, a strong convention (like Go's) of returning more than
  one value, one of which is an error flag you always need to check,
  isn't really encouraged[^1]

What mechanism should you use instead? Wrapsher takes inspiration
from its shell roots by favoring pre-checking. For example,
it's Wrapsher idiom to check a subscript before assigning a value
to its result; to check for the existence of a file before opening
it, etc.

This degree of pedantic style is cumbersome (and often inefficient)
for large systems but it's appopriate for the smaller programs
Wrapsher targets. It's easier to reason about what the program is
doing and easier to understand the code paths it takes.

[^1]: In fact, since the **pair** type is a first-class citizen in
  Wrapsher, you _could_ actually create an option type based on
  **pair** where the key described the return type like 'ok' or
  'error' and the value is either a normal return value or something
  else. But this throws away some of Wrapsher's limited type system,
  and isn't really necessary; and would be cumbersome to use without
  pattern-matching.

## Required functions

When implementing a type **mytype** , you should implement:[^3]

[^3]: Probably, at some point, will be required to implement by the compiler.

```wrapsher
mytype new() { }               # returns a zero-value instance of the type
string to_string(mytype i) { } # returns a "nice" string representation
string quote(mytype i) { }     # returns an eval-able string representation
```

You will probably want to implement some of the following, too:

```wrapsher
bool quote(mytype i)        { } # A string that corresponds with a literal value of your type
bool eq(mytype i, mytype o) { } # Allows == to operate on values of your type
bool gt(mytype i, mytype o) { } # If > is valid for the type
bool lt(mytype i, mytype o) { } # If < is valid for the type
anothertype at(mytype i)    { } # If subscripting makes sense for the type
```

You may want to implement some of the following:

```wrapsher
bool head(mytype i)               # These allow the type to be iterated over
bool tail(mytype i)
```

Internal to your basic type implementation functions, you may make
heavy use of `_as` to get at the storage type, manipulate it, then return
the result rewrapped as your type. If you intend users of your type to
be able to convert it to and from other types, you should add
<code>as\_<i>type</i></code> functions as needed.

## `init()`

You can define a unary `init()` function that operates on your module type, like so:

```wrapsher
module mymodule

bool init(module/<i>mymodule</i> m) {
  # Initialization code
}
```

This function will run when at the beginning of program execution. You
would use this to initialize globals that can't have a hardcoded
value, or that have a collection value.

The **core** module uses this function to check external command dependencies.


---

> <sub>Copyright (c) 2025 Mermaidpurse
> [MPL-2.0](https://www.mozilla.org/MPL/2.0/) (code)
> [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) (docs)</sub>
