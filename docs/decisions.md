# Decisions

These are a collection of design decisions that have been made
or need to be made, and their rationales.

## Overall Design

Here's some things that aren't important/things wrapsher shouldn't do:

- Readability of resulting shell scripts is not terribly important
  (you shouldn't arbitrarily make things cryptic unless it means
  harming the language; e.g., there's no good reason to allow
  variables that aren't valid sh variables), but while the shell
  script should pass its tests and maybe `shellcheck` (perhaps with
  certain style lints turned off) it's not terribly important that the
  result is a "good" shell script.
- The compiler/transpiler itself should produce a standalone tool and
  shouldn't be needed after transpiling/compilation but it's not important
  that it be self-hosting or anything like that. Wrapsher programs are
  likely to be pretty slow at text manipulation, unless we elegantly capture
  `sed`, `awk` and similar capabilities for parsing.[^3]
- It's definitely not important that it be a good shell or a shell at all,
  or be used to implement a shell. A REPL would be nice as tooling. This is
  somewhat complicated by the prohibition against bare expressions at
  the top-level.

[^3]: As a principle of design, Wrapsher would actually discourage the arbitrary
  composition and use of external commands. You should be able to count on and
  use a library interface rather than wrangle options or worry about what version
  of `jq` is installed. Wrapsher will try to make this easy, so if it does need
  to use `sed` for something, it will do all the figuring out for you, and you will
  interact with a Wrapsher interface, not `sed`'s. That said, something like 
  `system()` will be provided.

Things I like in various languages that would be nice to incorporate (someday?):

- Set/array/list comprehensions

Some ideas I had that don't seem feasible:

- Pipelines. I do like them in Powershell, I guess I like them in
  Elixir but they seem complicated and I think they actually result
  in Elixir being harder to read for a newcomer. I don't think they
  match Wrapsher's other syntax constructs very well, and since it
  has method chaining, that's pretty clear in terms of transformations,
  it just doesn't end with the variable being assigned, if the intent
  is a binding.

## Tools

Tools to implement:
- Emacs mode for basic electric editing and syntax highlighting for me
- LSP (`wrapsher lsp`) with syntax highlighting
- Syntax highlighting for github/other tools (regex-based)
- REPL (probably via `wrapsher` module)
- Automatic formatting
- Linting

## Path to Self-hosting

It would be nice to implement more and more of Wrapsher in Wrapsher
and eventually self-host. Here are some steps:

- Make `wrapsher.wsh` the master driver with subcommands implemented
  `git`-style (e.g. `wrapsher compile` can be implemented by
  `wrapsher-compile`, which is a Ruby program.
- Create a `wrapsher` module and make `wrapsher-compiler` an
  external dependency driven by the module. Implement `wrapsher-compile`
  in Wrapsher.
- Separate the parser into `wrapsher-parser`, `wrapsher-transformer` and
  use it to implement the parser in the `wrapsher` module. Make
  `wrapsher-generator` its own tool to do codegen.
- Implement REPL, LSP and other tooling in Wrapsher.
- Implement code generation in Wrapsher, replacing `wrapsher-generator`
- Implement parse tree transformation in Wrapsher, replacing `wrapsher-transformer`
- Finally, implement a PEG parser in Wrapsher (or use an external one
  that emits, say, a JSON AST, and a `json` module which surely exists
  by then; which if it's native may have been implemented with a PEG
  parser) and rewrite the grammar, removing Ruby.

## Shell Libraries

Some tools (e.g. CircleCI orbs) enforce a certain style
where you're supposed to provide a library of shell functions
containing callbacks which are invoked.

To support this use case, we should introduce a new keyword `lower`
which exposes the function (or item?) to the shell in the typical
way. In other words, `lower bool build(buildspec bs)` would create a
shell function actually named `build()` that lifts its shell arguments
to strings, then calls a wrapper function which converts the arguments
from strings to the required type (using in our example
`s.as_buildspec()`, runs the real wrapsher function,
then converts the return type to a string using `to_string()`
and prints it.

We should explicitly discourage this usage unless it's absolutely
necessary: the whole reason for wrapsher's existence is that
you don't have to write shell scripts, so it should only be used
for cases where you have no choice.

## `continue`, `break` and `return`

I feel like these are partly redundant. `break` and `return`
are basically the same thing, aren't they? Can I make `break`
take an argument and `break` from a function or is that too weird?
Maybe I just make them synonyms. I guess the expectation is that
`return` has a different scope, but do I really want to keep track
of these different scopes?

It's probably not that bad. Loops will probably be implemented
with `while :` and a continue variable, so `continue` and
`break` are pretty easy.

`return` is not that hard _if_ the compiler generates the
function postamble, which it doesn't (it's in `_wsh_run`).
I'm still not sure I want `return`. I guess people probably
want it for fail-fast guards (so the whole function body isn't wrapped
in `if { } else { if { } else { } } ...`.

## Variadic functions?

- No variadic functions (difficult, inconsistent, requires splatting).

## String interpolation?

I've reserved double-quoted syntax for string interpolation as a maybe.
I'm not sure if it's necessary or desirable. It complicates things quite
a bit and ends up having this "little language" problem that I don't
like regexes for, with `#{ }` or stuff. Maybe something like fstrings,
though again, is that really better than `sprintf`? Or something even
heavier-weight like mustache?

## Elsif? Switch-case?

Right now you have to do <code>if _cond_ { } else { if _cond_ { ... }
else { ... } }</code to get multiple case semantics. Nesting the blocks
is a little weird. What about matching multiple cases at once. Switch-case-style
or if-else style or both?

If if-elseif-else style, what's the keyword? Or do we just make the enclosing
block optional, so `else if` works (I like this better than `elsif`, `elif`).

I don't really like switch-case, too much syntax. It's powerful when combined
with pattern-matching/destructuring, but the purposeful inclusion of assignment
expressions in `if` statements is probably good enough:

```
any find(list l, k, d) {
  if not l? {
    return d
  }

  if (h = l.head()).key() == k {
    h.value()
  } else {
    l.tail().find(k)
  }
}
```

Note in the above pseudocode I used the `?` syntax which might be neat.
It's the same logic as `== typeof(l).new` but might be implemented
differently for each type.

## Interfaces, Unions or union types?

Right now if I want to make a function that accepts more than one
type of second argument, I need to make it accept `any` and then
do its own type assertion (which actually doesn't exist yet). For
example, to create a `add(float f, number n)`-style function that 
accepts ints and floats for `n`, you'd have to do something like:

```
float add(float f, any n) {
  if n.is_a(int) {
    n = n.as_float()
  } else {
    if not n.is_a(float) {
      throw something
    }
  }
  ... do things with n
}
```

Should this be made easier?

```
float add(float f, int | float n) {
...
}
```

I wouldn't want to see functions returning union types, and the function still
has to handle the branches.

Or... what if this is interfaces where I really just want a type that implements
a certain function or set of functions? If we required identity `as_` functions,
this could work?

```
float add(float f, float n.as_float()) {
}
```

Maybe I could even call the function and check the type of the result before binding?

Or

```
float add(float f, as_float() n) {
}
```

Do those make the parsing really hard?

Maybe introduce explicit interfaces?

```
interface can_float [as_float: float, times: float]
```

```
float add(float f, can_float n) {
  n = n.as_float()
}
```

That could tie nicely into structs.

I like the idea that interfaces are automatically implemented. Then again,
I have runtime type checking all over the place so if the type doesn't implement
the actual function there will be a failure. Hm.

### Function Interfaces

This would solve the somewhat clunky double-call required for funs. Right now
when you construct a lambda, it returns an item of time fun, the result of
calling `call()` on which is an item whose value is of
a unique type associated with the lambda, and accepts the right arguments.

If instead you could define an interface like `callable` or `filter_thunk`,
you could control the signature of the items passed into the function.

```
interface callable {
  any call(self item) # Is this literally what needs to be implemented
                  # or would the existence of 
}
```

```
interface stringfilter {
  bool call(string s)
}

stringlist filter(stringlist sl, stringfilter f) {
  sl._as(list).filter(bool fun (any e) { f.call(e) })
}
```

Something like that?


## "First class" structs?

You can manually implement your own struct, but this seems to be such
a common case that maybe something like `type foo struct [id: uuid, name: string]`
should be accepted (or maybe it's actually the zero value, and therefore also defines
the types: `type foo struct [id: uuid.new(), name: '']` and it will generate stuff like:

```
foo new(type/foo t) {
  [
    uuid.new(),
    ''
  ]._as(foo)
}

uuid id(foo i) {
  i._as(list).at(0)
}

foo set_id(foo i, uuid j) {
  i._as(list).set(0, j)._as(foo)
}

string name(foo i) {
  i._as(list).at(1)
}

foo set_name(foo i, string s) {
  i._as(list).set(1, s)
}
```

## Top-level expressions

Right now, the top-level kind of doesn't have expressions, or it does
in certain contexts but the VM implementation based on `return`
doesn't really work, in particular for list or map constants. For
eval, a REPL, and certain things like above where you want initial
global values to have collection values, that doesn't really work.

## Weird syntax ideas

### More operator overloading

'stringtwo,andthis,other' / ',' => list split(string s, string d) => ['stringtwo', 'andthis', 'other']

is s / ',' better than s.split(',')? Is this necessary?

### Assignment operators

`+=` is very popular: implement? What about `*=`, `-=`, etc.? I don't want `++` due to not making
mutation clear.

### `?` to test presence/nonzero

What if `x?` meant `x.is_zero()` and tested if `x` is equal to the
type's zero value? Does this over-encourage in-band semaphore values
as a substitute for optionality/error checking? Is it even useful?
Will I want a ternary operator later? If so, I don't think I'd want it
based on ` ... ? ... : ... ` because `:` is probably bound for
maps/pairs. `... && ... || ...` perhaps?

### Lambda calls

How about `f.(...)` as syntactic sugar for `f.call().with(...)`? or
`f->(...)`?

I think the other alternative (when I get there) is to use interfaces
so that functions can accept "objects with a call method that match this
signature" which is probably even better. Maybe not incompatible. But if
I want to encourage people on this path, we should probably leave the current
syntax clunky.

## Pairs for in-band errors

Basically we only have errors and they're not checked (at least not
now): there's no requirement to declare the errors you might throw
nor opportunity to see if you're doing something with them. They're
true error conditions--no valid value could be produced.

Wrapsher's design is that nullity and invalid values are impossible:
you can have an error but not a wrong answer. However, what about
results of varying validity, or things which are expected but unusual,
or unexpected but not invalid? Some possible patterns are
a well-known interface for maybes/optionals, or using pairs for
this with a convention for the pair's key (this would be particularly
good with destructuring in an assignment; or at least, fairly common).

I don't want to go full golang with the `ok, err` type stuff, but
a little

```
pair find(map m, any k, any d) {
  if m.has(k) {
    'found': m[k]
  } else {
    'notfound': d
  }
}
```

This tells you that the default was used _because it is the default_,
and it's not in your collection.

## Safety, "Namespaces" and modules

- Implement various warnings, lints and (overrideable errors), like:
    - Exactly one `module` for modules
    - No `module` for programs
    - "Foreign" module functions in a file without a `module` declaration
    - Override probably a pragma like `use ...`
    - `use feature` in a module

What about module namespaces? Maybe this is very simple and we can
just do `other/io`. So you do:

`use module other/io`

And you get `$INCLUDE_DIR/other/io.wsh`, that's very simple. In
    fact I think it just works now.

Does the module itself declare `module other/io` or `module io`? I
think it might be able to do either, but which is better. If `other/io`
then what if you _want_ it to be an alternate-but-exclusive implementation?
Like `jq/json` and `pureshell/json`, where you can do `json` types
but they are coming from different modules?

Since modules imply global variables with a module value, it's possible
to declare alternative implementations and replace them, perhaps. So you
could do:

`use module io`
`use module better/io`

bool init() {
  io = module/better/io.new() # or something
}

Now, types are not replaceable because you can't redefine a global with
a second type, but again you could alias them:

```
module better/file

type betterfile int

init() {
  file = type/betterfile.new() # or something
}

betterfile open(string filename) {
  ...
}
```

But it's probably generally better to just implement a `file`-like
interface.

<code>use module _version_</code> should be the one way you declare version
constraints. I don't want there to be a Wrapsherfile or separate dependency
solver outside of the language. If you have a dependency and you need a version
pin, that's a code dependency and belongs in the code.

Another thing to consider is how remote or third-party modules get loaded,
and the possibility of signed modules. Would it make sense to control
access to third-party modules via code-signing of some kind? Or is it
enough to rely on DNS and HTTPS security to verify the source location
is accurate? Does code-signing add any actual security?

## Serialization

For a variety of use cases, we should be able to round-trip serialized
constant terms. This ties in with being able to substitute parser components
(so that a wrapsher program can read complex data from an external program),
concurrency (so that wrapsher processes can communicate with each other)
and saving/restoring values. This might not be much more complicated than
re-escaping strings (which is easy because escaping is very simple) and
dumping them, possibly with decoration for wrapping.

## Concurrency/External Drivers

Part of using external programs efficiently is, when possible, not forking
for command substitution for every call. For example, it should be possible
to base the **math** module on `bc` (choosing `bc` over `dc` basically
for trig functions, so maybe it should be `dc` and there should be a **trig**
module) where maybe you get a calculator handle back (which represents
a persistent connection to a `bc` process). Need to think carefully because
it introduces a lot of complexity (what happens when it dies; prompting and
I/O deadlocks; reading from its stderr and stdout both) when maybe you
could get a lot of the way there by just crafting a very smart expression
in the first place.

But if you need to IPC with `bc` then you need the ability to IPC with other
wrapsher processes, so maybe there should be a **multiprocess** module
which forks and keeps handles (sets of fds, probably) open to communicating
subprocesses, waits for them, etc. You could even do a supervision
tree, queues and stuff. (This requires serialization for message-passing
on pipes). This could be useful enough on its own.

This goes beyond safe subprocesses (i.e. doing the `fork`, `exec` and
redirection properly). But lots of useful programs work only that way
so it's probably the first stop (e.g. `jq`).

So the priority is: safe command invocation and reading of output (required),
then multiprocessing, then seeing if multiprocessing can be leveraged for
persistent "command drivers" (are there any others than `bc`? Maybe `openssl`)
