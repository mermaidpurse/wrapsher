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

`vector:list:ref:1000 ref:1001 ref:1002`

All `_as_vector(l)` really does is strip the `vector` part,
exposing the underlying list.

## Function Calls

When a function call occurs:
- The function arguments are pushed onto the stack (`_wsh_stack<_wsh_stackp>`)
  in reverse order
- `_wsh_dispatch` (or, for nullary functions, `_wsh_dispatch_nullary`) is
  called, which peeks at the top argument to decide what function to dispatch
  to: either `_wshf_function_name_<type>` or `_wshf_function_name_any`,
  using `_wshp_function_name_<type>` and `_wshp_function_name_any` as
  semaphore variables
- Inside the function, the arguments are popped off the stack one by one and
  assigned to local variables
- Processing occurs
- Each expression sets `_wsh_result`, which forms the return value of the
  function
- Before returning, `_wsh_result` is (deeply) interrogated for refs which are
  added to a temporary protected list.
- Each variable is deeply destroyed by interrogating it for refs and destroying
  them unless they're on the protected list
- The variable is then `unset`

**PROBLEM:** This is not sufficient for either variable scopes or fixing reference leaks,
because the variable scope must be tied to the stack frame. You can't fix this by
making new global variables named after the function, because recursion. POSIX sh
just doesn't have true local variables.


Example using

```
int sum(list l) {
  if l.length() > 0 {
    l + sum(l.tail())
  } else {
    0
  }
}
```

Initial state:

```
_wshr_1001=int:5
_wshr_1005=int:3
_wshr_1008=int:1
_wshv_main_list_mylist=list:ref:1001 ref:1005 ref:1008
```

Call 1:
- `_wsh_stack_push "${_wshv_main_list_mylist}"`
- `_wsh_main_list_

### Reflist

Okay. So I think the stack frames/scopes could be implemented with a `_wsh_scope` variable,
which is used like this (and this is a better way to reference dynamic variables which are all over
the place (though setting needs an eval, so the actual API might change)

```
a = 0
a
```

```
_wsh_set a 'int:0'
$((_wshv_${_wsh_scope}_a))

_wsh_set() {
  : $((_wshv_${_wsh_scope}_${1} = "${2}"))
  # or
  eval "_wsh_${_wsh_scope}_${1}=\"${2}\""
}
```

The compiler, I think, can generate code to clean up local variables.

I think maybe the scopes are just the stack depth, incrementing and decrementing as functions
are called.

So in the scope, there's a wrapsher variable `_reflist` which keeps a list of
references that are created in the scope, and that are imported from another scope:

```
_wshp_ref_any=1
_wshf_ref_any() {
  ... make reference
  # incremenet refid
  # update current scope's reflist
  _wsh_set _reflist new-reflist-with-our-reference
  _wsh_result=ref:${_wsh_refid}
}
```

When going out of scope (at a function's end), the variables are cleaned up (the compiler generates
this list, I think).

Also, the references are all destroyed, EXCEPT for the ones we're passing out of scope. We do this
by scanning `_wsh_result` for refs (a big question for me is whether we need to do this deeply,
I think maybe) and protect them by putting them on a protected list. In fact this protected list
can be set along with `_wsh_result`, like `_wsh_outrefs`.

Then we destroy all the references by unsetting their ref variables.

So then: how do we clean up the references that are passed out of the scope. I think they get
imported into the `_reflist` of the calling scope. So this happens as part of function
calling. In fact, the child scope's "protected" reflist is actually there--because we can make
cleaning _that_ variable up a responsibility of the parent scope. So it doesn't need to rescan
`_wsh_result`.

So after the funcall, in the parent scope, you import the `_wsh_outrefs` into `_reflist`
(`_wshv_${scope}__reflist`). And the cycle starts over. Those references are available for
cleanup, _unless_ they're passed out of the scope into a parent scope.

Does this work?

Note that globals don't get cleaned up, and somehow their refs, _if referenced_, need to not be as well. I'm
not 100% sure. Maybe global assignment removes the references from the current scope, preventing
them from being cleaned up. But in the case like setting a module value:

```
bool set_sync(module/file m, bool flag) {
  file = m.set('sync', flag)
}
```

Somehow the assignment to a global variable needs to also protect the refs. Also, the child scope
is not responsible for cleaning up refs that get passed in, but what about the ref that's the old
value of `sync`, above? Maybe you just get garbage with globals, and shouldn't use them very much!

But you still need a way to pass them out of scope by protecting them; but without importing them
into a calling scope. I think maybe they just get removed from the scope-local `_reflist`. This means
that global variable assignment is special. I think the compiler can know about globals, maybe
they're their own kind of thing.

Another possibility is that globals can only have immediate values. This suggests there might be
a simplified kind of list with immediate values that aren't fully strings or something.
