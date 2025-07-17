# Internals

The internal representation of wrapsher code (that is, the
shell representation) is documented here. The language
is implemented across the [`preamble.sh`](./lib/wrapsher/preamble.sh),
the [`postamble.sh`](./lib/wrapsher/postamble.sh) (mostly for
the program entry point, i.e., how `main` gets called), the
compiler (which generates `sh` code for programs) and
the [**core** module](./wsh/core.wsh). The core module contains
a lot of code written directly in shell in order to provide
the necessary fundamental functions. The `preamble.sh` is not
very large and contains some utilities.

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
means that the **list** type "wraps" the **reflist**, so its
raw `sh` strings look like this:

`list:reflist:ref:1001 ref:1002`

When a user implements a type, they choose a storage type (they
can also choose **builtin**, but since the compiler doesn't
know about the type, they'll need to write the raw shell
code necessary for accessing the value, so it's usually easier
to base a type on an existing builtin).

The `any _as(any i, any as)` function allows a value to be
wrapped--that is, cast from its type to another type that uses its
type as a storage type; or unwrapped--that is, cast from its type to
its own type's storage type. There is validation to this, but
it amounts to adding or removing a type tag at the beginning of
the value.

## References

Collections (lists) are implemented with underlying data types
**ref** and **reflist**. The **list** functions create references
when items are pushed onto the list, and push the reference into
the "inner" **reflist**; then dereference the items that are
accessed from the list.

A **reflist** is simply a space-separated list of references:

```
reflist:ref:1000 ref:1020 ref:1022
```

It's not typical to handle references directly in Wrapsher, but it's necessary
for collections so that collections can be represented as shell strings and
can be complex (lists of lists).

Since Wrapsher has references, this can lead to garbage. Wrapsher's approach is
to use a "borrow" approach where each frame is responsible for cleaning up any
references which are created in its scope and which are _not_ passed outside
of the frame. It does this by keeping a reference list in the magic local
variable `_reflist` (it's a Wrapsher variable), which is added to by the
`ref ref(any i)` function whenever a reference is created, and is automatically
added to by the VM when a result value from a function call contains references.

This is potentially expensive for large or deeply-nested data, since the Wrapsher
VM scans every return value for references and imports the result into the calling
frame's reflist.

## Function Calls

When a function call occurs:
- The function arguments are pushed onto the stack (`_wsh_stack<_wsh_stackp>`)
  in reverse order
- `_wsh_dispatch` is called with an arity based on the syntax of the function
  call. It  peeks at the top argument to decide what function to dispatch
  to: either `_wshf_function_name_<type>` or `_wshf_function_name_any`,
  using `_wshp_function_name_<type>` and `_wshp_function_name_any` as
  signal variables (the compiler creates these functions from Wrapsher functions).
- The function runner (`_wsh_run`) creates a new frame scope and
  initializes the reflist and list of variable names
- Inside the function (generated code), the arguments are popped off
  the stack one by one and assigned to local variables
- Processing occurs
- Each expression sets `_wsh_result`, which forms the return value of the
  function
- Before returning, `_wsh_result` is (deeply) interrogated for refs which are
  added to a temporary protected list.
- Any references which were created were added to the local `_reflist`
  Wrapsher variable. Any unprotected references are destroyed.
- Each local variable is then `unset`

Most expressions in Wrapsher are syntactic sugar for function calls;
internally, you can say Wrapsher uses a functional style or even that
it is close to being a Lisp.

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

The `_wsh_error` is the standard variables to use to set an error
condition. At each call level (i.e., when `_wsh_dispatch` is called),
the variable is examined and the error is propagated if this variable
is not empty.

Each `sh` function body is wrapped in a single-execution `while`
loop that can be `break`-ed when a function call sets `_wsh_error`.
When this happens, context information is added to the error (a new
line of call context information). The function body which called
the function which threw the error now `break`s its own governing
`while` loop, and so on.

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

Most functions that "return" values actually set a variable whose name
you pass to the function.

Wrapsher convention is to use `_wshi`, `_wshj` as temporary variables
whose value you use right after setting it. Don't proliferate shell
variables.

### <code>_wsh_get_local <i>wrapsher_varname</i> <i>shell_variable</i></code>

This function retrieves a local variable into the shell varable that you
provide.

### <code>_wsh_set_local <i>wrapsher_varname</i> <i>value</i></code>

This function sets a local variable (both adds it to the frame's pending
cleanup list and sets a variable whose value can be retrieved with
`_wsh_get_local`.

### `_wsh_get_global` and `_wsh_set_local`

These operate similarly to their local equivalents. Note that in general,
Wrapsher compiled code does not need `_wsh_set_global` since the compiler
arranges to call the direct assignment operation.
