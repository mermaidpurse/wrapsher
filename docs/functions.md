# Functions

Wrapsher has single polymorphic function dispatch, so functions are
dispatched on the type of the first argument.

## Redefinition

Wrapsher functions are global in namespace and do not allow for
redefinition **UNIMPLEMENTED**. This has implications that any
module can define a function in any "namespace" (for example, a
module can define a `main` function, meaning that when you
`use` that module in a program, that will be your entry point
for the program, and you can't provide your own `main`.

This 

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

## Function dispatch/polymorphism

Funtions are dispatched based on the type of the first argument (and
only the type of the first argument). Functions are global in nature
but this polymorphism allows functions to be organized by modules and/or
types.

The function signature defines the type that the function accepts as
the first argument. Consider the following function signature of
a "module function":

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

When you do `type vector list`, a global variable `vector`
is created of type `type/vector`, enabling you to write
`vector.new()` or (equivalently) `new(vector)`.

See [modules-types.md](./modules-types.md) for more discussion of how
types work.

## as_ and to_ functions

The convention in Wrapsher is that types are converted to each other
("casted") using both <code>as_<i>type</i>()</code> and <code>to_<i>type</i>()</code>
functions. When present, they serve slightly different purposes:

The <code>as_<i>type</i>()</code> should be used for an "identity"
cast.  <code>_type_ as_<i>type</i>(_type_ i)</code> is automatically
implemented for every type (**UNIMPLEMENTED**) as an identity
conversion, and a cast to and from the type's "storage" type _should_
be implemented. An identity cast is round-trip, and serves as a
canonical, if internal representation of the type.

For example, if defining `type stringlist list` to make a list
of strings, you should implement `list as_list(stringlist s)`
and `stringlist as_stringlist(list l)`, probably taking
advantage of the automatically-implemented unsafe casts:

```
stringlist as_stringlist(list l) {
  l._as_stringlist()
}

list as_stringlist(list l) {
  l.map(fun (any i) { i.assert(string) })
  l._as_list()
}
```

When implemented, a `to_` function isn't expected to provide
an identical value, but a one-way conversion. For example,
you might implement `to_string()` to provide a friendly
representation of your type, but it's not unambiguous and conceptually
you wouldn't need to be able to read the resulting value
back into the type. It's okay to leave information out of a
`.to_` conversion.

## Anonymous functions

**UNIMPLEMENTED**

An anonymous function definition takes the form of a return type, the
keyword `fun` and a function signature. For example, you might define
a function and assign it to a variable, or pass it to a conventional
function call:

```
int main(list args) {
  ints = args.map(int fun(string s) { s.to_int() })
}
```

The result in `ints` will be an list of ints that result from calling
the anonymous function on each (`string`) element of the list `args`.

