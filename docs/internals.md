# Internals

## Internal type implementations

Since Wrapsher is running in a POSIX shell, it uses a simple
tagged value scheme for tracking type information. Each value
is tagged like this:

`<type>:<value>`

Since only strings are available, it means that something more
complicated is required for collection types `map` and `list`.

These are actually reference-based, but the reference mechanism
is internal to Wrapsher and will probably not be exposed. References
are cleaned up when the collections are modified. Internally,
a three-member list of strings looks something like this:

`list:ref:1000 ref:1001 ref:1002`

When you access an list member, it is dereferenced (it's a reference
to a shell variable out there named something like `_wshr_1001`.

References are never shared; this is not subject to garbage collection
problems. This is only a mechanism to ease handling of data that has
to occur in shell strings.

When a type is wrapped by declaring a new type, it gets prepended
to the value. So after we've created our vector, it'll internally
look something like:

`vector:list:reflist:ref:1000 ref:1001 ref:1002`

All `_as_vector(l)` really does is strip the `vector` part,
exposing the underlying list.

## References

Collections (lists) are implemented with underlying data types
**ref** and **reflist**. The only difference between a **reflist** and
a **list** is that a **list** dereferences its elements when used.

A **reflist** is simply a list of references. In the Wrapsher internal implementation,
it's a space-separated list:

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
- `_wsh_dispatch` (or, for nullary functions, `_wsh_dispatch_nullary`) is
  called, which peeks at the top argument to decide what function to dispatch
  to: either `_wshf_function_name_<type>` or `_wshf_function_name_any`,
  using `_wshp_function_name_<type>` and `_wshp_function_name_any` as
  semaphore variables
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

## VM Functions

The Wrapsher "virtual machine" is composed of certain shell functions
implemented in the [`preamble.sh`](../lib/wrapsher/preamble.sh) and
`postamble.sh`(../lib/wrapsher/postamble.sh) code snippets included
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
