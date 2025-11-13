# Internals

The internal representation of wrapsher code (that is, the
shell representation) is documented here. The language
is implemented across the [`preamble.sh`](./lib/wrapsher/preamble.sh),
the [`postamble.sh`](./lib/wrapsher/postamble.sh) (mostly for
the program entry point, i.e., how `main` gets called), the
compiler (which generates `sh` code for programs) and
the [**core** module](./wsh/core.wsh). The core module contains
a lot of code written directly in shell in order to provide
the necessary fundamental functions.

Note that Wrapsher's philosophy is to rely, especially for core
functionality, only on POSIX-required behaviors. Many shells
implement collection types, for example, or local variables;
Wrapsher doesn't use these because they are not required by POSIX.
You should be able to run Wrapsher programs on any platform
with a compliant shell; not just when certain versions of `bash`
are installed, for example.

Wrapsher also tries to avoid unnecessary forking and subshells;
so, for example, since the `[` or `test` command is not required
to be builtin, it mostly uses `case` for conditional expressions,
and for its own conditionals.

## Internal type implementations

Since Wrapsher is running in a POSIX shell, it uses a simple
tagged value scheme for tracking type information (all values
are represented by strings; by necessity). Each value
is tagged like this:

`<type>:<value>`

Some Wrapsher types are builtin, and some are based on another type
(the "store type"). For example, the **list** type (and the **pair**
and **map** types) are based on the builtin **reflist** type. This
means that the **list** type "wraps" the **reflist**, so its raw `sh`
strings look like this: `list+reflist:ref:1001 ref:1002`.

When a user implements a type, they choose a storage type[^1]. They'll
probably write the corresponding methods that use that type as a receiver
as manipulations of the underlying storage type, relying on `_as` to
unwrap the type to expose the underlying methods.

[^1]: They can also choose **builtin**, but since the compiler doesn't
  know about the type, they'll need to write all the raw shell code
  necessary for accessing the value, so it's usually easier to base a
  type on an existing builtin).

The `any _as(any i, any as)` function allows a value to be
wrapped--that is, cast from its type to another type that uses its
type as a storage type; or unwrapped--that is, cast from its type to
its own type's storage type. There is validation to this, but
it amounts to adding or removing a type tag at the beginning of
the value.

## References

Collections (such as lists and pairs) are implemented with underlying
data types **ref** and **reflist**. The **list** functions create
references when items are pushed onto the list, and push the reference
into the "inner" **reflist**; then dereference the items when
accessed from the list.

Internally, i.e., to the shell, a **reflist** is simply a
space-separated list of references:

```wrapsher
reflist:ref:1000 ref:1020 ref:2022:1012
```

It's not typical to handle references directly in Wrapsher, but the
mechanism is necessary for collections so that they can be
represented as shell strings and can be complex (lists including
lists, maps, pairs, etc.)

Since Wrapsher has references, this can lead to garbage. Wrapsher's
approach is to use a "borrow" approach where each frame is responsible
for cleaning up any references which are created in its scope and
which are _not_ passed outside of the frame. It does this by keeping a
reference list in a magic local variable `_reflist` (it's a real Wrapsher
variable), which is added to by the `_wsh_makeref_into` shell function whenever
a reference is created.

When a reference is taken to something that can itself contain
references (i.e. a value whose type has a storage type of `ref` or
`reflist`), the underlying reference Ids are included in the reference
itself. So when the scanner scans the references being passed out of
the frame, it doesn't need to deeply dereference the references--every
reference carries its underlying references with it.

## Function Calls

When a function call occurs:
- The function arguments are pushed onto the stack
  (<code>_wsh_stack<i>_wsh_stackp</i></code>) in reverse order
- The `_wsh_dispatch` shell function is called with an arity based on
  the syntax of the function call. It peeks at the top argument to
  decide what function to dispatch to: either
  <code>_wshf_function_name_<i>type</i></code> or
  `_wshf_function_name_any`, using
  <code>_wshp_function_name_<i>type</i></code> and
  `_wshp_function_name_any` as signal variables (the compiler creates
  these functions from Wrapsher functions).
- The function runner (`_wsh_run`) creates a new frame scope and
  initializes the reflist (`_reflist`, a real local Wrapsher variable)
  and list of variable names
- Inside the function (generated code), the arguments are popped off
  the stack one by one and assigned to local variables
- Processing occurs according to generated code
- Each expression sets `_wsh_result`, the last result of which forms
  the return value of the function
- Before returning, `_wsh_result` is examined for refs which are
  added to a temporary protected list.
- Any references which were created were added to the (parent frame's)
  local `_reflist` Wrapsher variable. Any unprotected references are
  destroyed.
- Each local variable's underlying shell variable is then `unset`

Most expressions in Wrapsher are syntactic sugar for function calls;
internally, you can say Wrapsher uses a functional style or even that
it is close to being a Lisp.

## Maps

Maps are currently implemented as pairlists: that is, finding a map
value is done by linear search of the list of pairs to find a pair
that has a key that equals the search key.

This is inefficient and may be changed in the future to a tree or
hash table implementation.

## Funs

Wrapsher's anonymous functions work by creating a special, single-use
type for the lambda; by creating a `with` function that operates on
that type and has the lambda's signature and body; and by creating
a value of that type that contains a map of the variable bindings
the lambda closes over, then wrapping that as a `fun` type so it
can be passed around as a value.

The `with` function is a real, named Wrapsher function operating
on the single-use type.

## Errors

The `_wsh_error` is the standard variable to use to set an error
condition. At each call level (i.e., when `_wsh_dispatch` is called),
the variable is examined and the error is propagated if this variable
is not empty.

Each `sh` function body is wrapped in a single-execution `while`
loop that can be `break`-ed when a function call sets `_wsh_error`.
When this happens, context information is added to the error (a new
line of call context information). The function body which called
the function which threw the error now `break`s its own governing
`while` loop, and so on, which is how the call stack is added
to errors.

Try blocks are implemented as `while` loops of their own, so that
errors can be caught.

Wrapsher `while` loops are _also_ implemented as `while` loops, so
at the conclusion of each, `_wsh_error` is examined so that
`break`s that occur due to error propagation are distinguished from
`break`s due to Wrapsher `break`s.

## VM Functions

The Wrapsher "virtual machine" is composed of certain shell functions
implemented in the [`preamble.sh`](../lib/wrapsher/preamble.sh) and
[`postamble.sh`](../lib/wrapsher/postamble.sh) code snippets included
every compiled Wrapsher program.

Functions in the preamble that "return" values do so either by setting
a well-known global variable (e.g., `_wsh_typeof` sets `_wsh_type`)
or by setting a variable whose name is passed into the function; the latter
by convention are named <code>_wsh_<i>something</i>_into</code>.

Wrapsher convention is to use `_wshi`, `_wshj` as temporary variables
whose value you use right after setting it. It's a goal not to proliferate
shell variables overmuch, so you can imagine these a little like registers.

### <code>_wsh_get_local <i>wrapsher_varname</i> <i>shell_variable</i></code>

This function retrieves a local variable into the shell varable whose name
you provide.

### <code>_wsh_set_local <i>wrapsher_varname</i> <i>value</i></code>

This function sets a local variable (both adds it to the frame's pending
cleanup list and sets a variable whose value can be retrieved with
`_wsh_get_local`.

### `_wsh_get_global` and `_wsh_set_local`

These operate similarly to their local equivalents. Note that in general,
Wrapsher compiled code does not need `_wsh_set_global` since the compiler
arranges to call the direct assignment operation.

### <code>_wsh_makeref_into <i>value</i> <i>shell\_varname</i></code>

This creates a reference to the value and provides the resulting
`ref` value in the named variable.

### <code>_wsh_deref_into <i>ref\_value</i> <i>shell\_varname</i></code>

This dereferences the value and provides the value in the
named variable.

---

> <sub>Copyright (c) 2025 Mermaidpurse
> [MPL-2.0](https://www.mozilla.org/MPL/2.0/) (code)
> [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) (docs)</sub>
