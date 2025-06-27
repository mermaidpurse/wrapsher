# Wrapsher has polymorphic function dispatch

## Receiver syntax

Wrapsher has syntactic sugar so that a function invoked in receiver
style is dispatched as if the receiver is its first argument. In other
words, the following function calls are equivalent:


| **Receiver** | **Conventional** |
| === | === |
| `io.println(mystring)` | `println(io, mystring)` |
| `fh.write(mystring)` | `write(fh, mystring)` |
| `strip(mystring)` | `mystring.strip()` |
| `io.println(mystring.strip())` | `println(io, strip(mystring))` |

Of course, functions can be defined and called that take no arguments
(nullary).

By convention, because the first argument is important, it's usually
called the receiver, whether it's written that way or not.

# Function dispatch/polymorphism

Funtions are dispatched based on the type of the first argument (and
only the type of the first argument). Functions are global in nature
but this polymorphism allows functions to be organized by modules and/or
types.

The function signature defines the type that the function accepts as
the first argument. Consider the following function signature:

```
int println(module/io m, string s) {
```

When `println(x)` is invoked, the type of `x` is examined.
Iff `x` is of type `module/io`, then this function is selected.

When you do `use module io`, a global variable is created that
has type `module/io` and an opaque value.

Similar dispatch works for type types: that is, functions that
operate on the type itself, rather than an instance of the type;
typically type constructors.

When you do `type vector array`, a global variable `vector`
is created of type `type/vector`, enabling you to write
`vector.new()` or (equivalently) `new(vector)`.

See [modules-types.md](./modules-types.md) for more discussion of how
types work.
