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
