# Functions

Wrapsher has single polymorphic function dispatch, so functions are
dispatched on the type of the first argument.

## Redefinition

Wrapsher functions are global in namespace and do not allow for
redefinition (that is, two functions of the same name and receiver type
can't coexist). Any module can define a function in any "namespace" (for
example, a module can define a `main` function, meaning that when you
`use` that module in a program, that will be your entry point for the
program, and you can't provide your own `main`.

However, Wrapsher uses its polymorphic function dispatch to provide
a close match for module and type namespacing. There's no reason
you can't have many `open()` functions, all operating on a given type.

## Receiver syntax

Wrapsher has syntactic sugar so that a function invoked in receiver
style is dispatched as if the receiver is its first argument. In other
words, the following function calls are equivalent:


| Receiver | Conventional |
| :------- | :----------- |
| `io.println(mystring)` | `println(io, mystring)` |
| `fh.write(mystring)` | `write(fh, mystring)` |
| `mystring.strip()` | `strip(mystring)` |
| `io.println(mystring.strip())` | `println(io, strip(mystring))` |
| `mystring.split().length()` | `length(split(mystring))` |

Of course, functions can be defined and called that take no arguments
(nullary).

By convention, because the first argument is used in resolving
function dispatch, it's usually called the receiver, whether it's
written that way or not.

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

If there is no function implemented against the type, then Wrapsher
will "fall back" to a function of the same name implemented against
the `any` type. If there is no such function, this results in
an error.

## Conversions, casts and `quote()`

The convention in Wrapsher is that types can be converted to each
other using both <code>as_<i>type</i>()</code> and
<code>to_<i>type</i>()</code> functions. When present (they need not
be), they serve slightly different purposes:

The <code>as_<i>type</i>()</code> conversion is a safe cast. That is,
the result is exactly equivalent to the input, but of a different
type. An error is produced if the exact, safe conversion can't
be performed. Casting to and from a type's store\_type can usually
be performed.

A <code>to_<i>type</i>()</code> conversion is a conversion, which
_may_ result in an error if the input type is invalid. It is not
necessarily round-trippable; it may not include all the information
in the source and may reflect parsing or other operations. For
example, an integer is parsed out of a string with `int to_int(string s)`,
not directly cast. All types implement a `to_string()` method
which can be used to produce a "nice" output value; but you would
not necessarily expect to be able to parse the exact value back
from the resulting string.

The `quote()` function is designed to produce a Wrapsher-eval-able[^1]
representation of a value. For example, using `quote(s)` where `s`
is a string will return a string that, output, includes its quotes
and escapse internal quotes and backslashes, so it coudl be used
as a literal in a Wrapsher program.

[^1]: Although, as of this writing, Wrapsher does not have `eval`.

Wrapsher doesn't have "unsafe" casts where you just assert that
a type is of a different type. You need to write a converter to
make the conversion.

For example, if defining `type stringlist list` to make a list
of strings, you should implement `list as_list(stringlist s)`
and `stringlist as_stringlist(list l)`, probably taking
advantage of the `_as()` function, which wraps or unwraps
a value to or from its storage type.

```
stringlist as_stringlist(list l) {
  l._as(stringlist)
}

list as_stringlist(list l) {
  l.map(fun (any i) { i.assert(string) })
  l._as(list)
}
```

## Anonymous functions

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

Anonymous functions are closures and contain the local variables that were
in scope when it was created. This allows you to make factory functions:

```
fun multiplier(int i) {
  int fun (j) { i * j }
}

int main(list args) {
  f = multiplier(10)
  [0, 1, 2].map(multiplier) # => [0, 10, 20]
}
```
