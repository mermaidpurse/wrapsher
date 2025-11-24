# Decisions (Design and Musings)

These are a (somewhat random) collection of design decisions that have
been made or need to be made, and their rationales.

## Tools

Tools to implement:
- Emacs mode for basic electric editing and syntax highlighting for me
- LSP (`wrapsher lsp`) with syntax highlighting
- Syntax highlighting for github/other tools (regex-based)
- REPL (probably via a `wrapsher` module)
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

Also, it would be difficult the way things currently work to
create two wrapsher libraries that could both be loaded, so it
would be strictly one at a time.

## Variadic functions?

I don't think Wrapsher will ever have variadic functions: they imply
an inconsistent interface and require a splatting syntax of some kind,
and are therefore messy. Something like `io.printf(string fmt, list args)`
works just as well.

## Functions by name?

Can function names have a fun value?

```wrapsher
l.map(to_string)
```
instead of

```wrapsher
l.map(string fun (any i) { i.to_string() } # useless wrapper
```


## Enums

How to represent enums? This probably needs top-level list constants
like structs.

```wrapsher
type foo enum [...]
```

Only basic types? Or something richer?

## Interfaces, Unions or union types?

Right now if I want to make a function that accepts more than one type
of second argument, I need to make it accept `any` and then do its own
type assertion. For example, to create a `add(float f, number
n)`-style function that accepts ints and floats for `n`, you'd have to
do something like:

```wrapsher
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

```wrapsher
float add(float f, int | float n) {
...
}
```

I wouldn't want to see functions returning union types, and the function still
has to handle the branches.

Or... what if this is interfaces where I really just want a type that implements
a certain function or set of functions? If we required identity `as_` functions,
this could work?

```wrapsher
float add(float f, float n.as_float()) {
}
```

Maybe I could even call the function and check the type of the result before binding?

Or

```wrapsher
float add(float f, as_float() n) {
}
```

Do those make the parsing really hard?

Maybe introduce explicit interfaces?

```wrapsher
interface can_float [as_float: float, times: float]
```

```wrapsher
float add(float f, can_float n) {
  n = n.as_float()
}
```

I like the idea that interfaces are automatically implemented. Then again,
I have runtime type checking all over the place so if the type doesn't implement
the actual function there will be a failure. Hm.

**iterable** (has `head()`, `tail()` and `zero()`) would be a good candidate
for a standard interface.

So would **comparable** (`eq()` and/or `gt()` and `lt()`).

### Function Interfaces

This would solve the somewhat clunky double-call required for
funs. Right now when you construct a lambda, it returns an item of
type fun, the result of calling `call()` on which is an item whose
value is of a unique type associated with the lambda, and whose
`with()` function accepts the right arguments.

If instead you could define an interface like `callable` or
`filter_thunk`, you could control the signature of the items passed
into the function.

```wrapsher
interface stringfilter {
  bool call(string s)
}

stringlist filter(stringlist sl, stringfilter f) {
  sl._as(list).filter(bool fun (any e) { f.call(e) })
}
```

Something like that? Or `call_with` so it's compatible with
general funs?

## Top-level expressions

Right now, the top-level kind of doesn't have expressions, or it does
in certain contexts but the VM implementation based on `return`
doesn't really work (actually, this no longer applies), in particular
for list or map constants. For eval, a REPL, and certain things like
above where you want initial global values to have collection values,
that doesn't really work.

It would be overall cleaner if the current "statements" like `use ...`
were expressions too.

## Weird syntax ideas

### More operator overloading

```wrapsher
'stringtwo,andthis,other' / ',' => list split(string s, string d) => ['stringtwo', 'andthis', 'other']
```

Is `s / ','` better than `s.split(',')`? Is this necessary? I find
it attractive and clever but is this a good enough reason to implement?

### Assignment operators

`+=` is very popular: implement? What about `*=`, `-=`, etc.? I don't
want `++` due to not making mutation clear. Since I haven't chosen to
put assignment behind `:=` or something, and it's just `=`, I don't want
operators other than those containing `=` to be doing assignment.

### `?` to test presence/nonzero

What if `x?` meant `x.is_zero().not()` and tested if `x` is equal to the
type's zero value? Does this over-encourage in-band semaphore values
as a substitute for optionality/error checking? Is it even useful?
Will I want a ternary operator later? If so, I don't think I'd want it
based on ` ... ? ... : ... ` because `:` is probably bound for
maps/pairs. `... && ... || ...` perhaps, like shell?

### Lambda calls

How about `f.(...)` as syntactic sugar for `f.call().with(...)`? or
`f->(...)`?

I think the other alternative (when I get there) is to use interfaces
so that functions can accept "objects with a call method that match this
signature" which is probably even better. Maybe not incompatible. But if
I want to encourage people on this path, we should probably leave the current
syntax clunky.

### Destructors?

Having to close things that you open is definitely not friendly. Right now,
local variables are cleaned up by the compiler. Is there some way to arrange
for a destructor to run, if one exists? It could be a special dispatch
that examines the type and looks at the appropriate shell function predicate
(e.g. corresponding to something like this):


```wrapsher
bool destroy(io_handle fh) {
  fh.fd().close()
}
```


## Pairs for in-band errors

Basically we only have unstructured errors and they're not checked (at
least not now): there's no requirement to declare the errors you might
throw nor opportunity to see if you're doing something with
them. They're true error conditions--no valid value could be produced.

Wrapsher's design is that nullity and invalid values are impossible:
you can have an error but not a wrong answer. However, what about
results of varying validity, or things which are expected but unusual,
or unexpected but not invalid? Some possible patterns are
a well-known interface for maybes/optionals, or using pairs for
this with a convention for the pair's key (this would be particularly
good with destructuring in an assignment; or at least, fairly common).

I don't want to go full golang with the `ok, err` type stuff, but
maybe a little of this kind of thing wouldn't be so bad:

```wrapsher
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

## Type Expressions, Narrowing

What if type narrowing could exclude methods you want to write?

It would be nice to be able to extend types in some way, without becoming
object-oriented. The `type <typename> [<field>: <type>...]` syntax
worked really well for structs, as did the compiler macros to help with
generated AST. I've been thinking about using a similar syntax for
enums, but if I do I probably can only enum basic types, so maybe that
should wait. There definitely needs to be some kind of enum, though.

But, a really common thing to want to do is to narrow the collection
types. One way could be to use a function syntax for the type expression
and use it to generate narrowed versions of the functions against the
base type. For example, for `list`:

`type list/string list(string)`

I think we actually want this one automatically anyway because it's the
type of the arguments in `main`. The idea is that the compiler uses
the expression `list(string)` to mean "for every function F with
receiver `list`, generate a function with receiver `list/string`,
but replace any `any` arguments or the return value with `string`.

Would that work if we want:

`type map/string/int map(pair(string, int))`

Or would we have to do

```
type pair/string/int pair(string, int)
type map/string/int map(pair/string/int)
```

That actually makes sense, because in something like:

```
pair new(type/pair) => pair/string/int new(type/pair/string/int)
pair from_kv(any k, any v) => pair/string/int from_kv(string k, int v)
any key(pair p) => string key(pair/string/int p)
??? int value(pair p) => int value(pair/string/int p) ??? How would it know?
```

That's close but not quite there. It definitely makes sense for a list, though. Could it
make sense for arbitrary types? Or... should I just implement list/string and leave it
up to the user for now?

I should probably just implement list/string and leave this macro to stew for a little more.

Okay, how about this: only missing methods get generated, so:

```
type pair/string pair(string)

any value(pair/string ps) {
  ps._as(pair).value()
}

type pair/string/int pair/string(int)
```

That would work because you only narrow one `any` at a time and override the
methods that can't be generated.


## Safety, "Namespaces" and modules

- Implement various warnings, lints and (overrideable errors), like:
    - Exactly one `module` for modules
    - No `module` for programs
    - "Foreign" module functions in a file without a `module` declaration;
      that is, functions with a module-type receiver but for a module other
      than the current one.
    - Override probably a pragma like `use ...`
    - `use feature` in a module (prohibit)

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

```
use module io
use module better/io

bool init() {
  io = module/better/io.new() # or something
}
```

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

## Module Loading

<code>use module _version_</code> should be the one way you declare version
constraints. I don't want there to be a Wrapsherfile or separate dependency
solver outside of the language. If you have a dependency and you need a version
pin, that's a code dependency and belongs in the code.

Another thing to consider is how remote or third-party modules get loaded,
and the possibility of signed modules. Would it make sense to control
access to third-party modules via code-signing of some kind? Or is it
enough to rely on DNS and HTTPS security to verify the source location
is accurate? Does code-signing add any actual security?

Maybe globals are kind of associated with a module (appear after a module
statement, or when they're brought in as a module) and you can only
bind a global in its own module? This probably has to be overridable
somehow.

## Serialization

For a variety of use cases, we should be able to round-trip serialized
constant terms. This ties in with being able to substitute parser components
(so that a wrapsher program can read complex data from an external program),
concurrency (so that wrapsher processes can communicate with each other)
and saving/restoring values. This might not be much more complicated than
re-escaping strings (which is easy because escaping is very simple) and
dumping them, possibly with decoration for wrapping.

_Note: implemented `quote()`_

I think this is related to needing compiler-generated literals for
collections. Function calls are pretty expensive so this really affects
startup time, just for the informational globals `_functions` and
so on. The compiler should at least be able to generate all the refs
and start the program with an initial refid that's greater than what
it used. So probably the compiler should inline shell code to initialize
the refs for constant collections and start the program with an initial
refid.

## Philosophy - Little languages and cleanliness

There are a lot of places where a programming languages acquires these
little mini-languages and while sometimes useful, I think they always
indicate a problem. Regular expressions (when they get baked into the
language somehow) are a big example of this, but so are formatting
specifiers (e.g. Lisp `format`, C and friends `printf`, Powershell/C#
format strings) and string interpolation and that's why I've punted on
providing these things for now. When they are needed, I want them to
be very thought out and not interfere with the core language, but be
a natural extension of it.

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

Need to look a lot more into file descriptor handling, I/O and subshells
and job control for this.

## Shellchecks

At some point I'll probably add shellchecks in the pipeline to test
generated programs. Here is what it's currently reporting:

- shellchecks
    - `SC3003 (warning): In POSIX sh, $'..' is undefined.`
        - [they're documented
          here](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html#tag_19_02_04),
          but when did it get added? are lots of old shells missing
          this?
    - `SC3045 (warning): In POSIX sh, read -d is undefined.`
        - [read has -d and is required to be intrinsic](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/read.html), but when did it get added? are lots of old shells missing this?
    -
        ```
        In wsh/core_test line 3833:
         _wsh_result="int:$((${_wshi#int:} ${_wshk#string:} ${_wshj#int:}))"
                          ^-- SC1102 (error): Shells disambiguate $(( differently or not at all. For $(command substitution), add space after $( . For $((arithmetics)), fix parsing errors.
        ```
    - It may be a good idea to do the arithmetic substitution
      differently, that should be easy enough
    - shellcheck reports many unreachable lines, configure out
    - It would probably be a big pain if there's some problem with
      reading literals the way I am with `read` and the here-documents
      with the start and end markers, and being able to use `$'\n'` in
      stripping the end marker. It's otherwise very difficult to read
      string literals safely and preserve characters like trailing
      newlines, etc., exactly. I'm really _really_ trying to avoid an
      encoding scheme for strings.

## Future Ideas

Things I like in various languages that would be nice to incorporate (someday?):

- Set/array/list comprehensions: I do love a comprehension

`[ x: y | x <- all_things; y <- iter() ]`

Some ideas I had that don't seem feasible/don't like:

- Pipelines. I do like them in Powershell, I guess I like them in
  Elixir but they seem complicated and I think they actually result
  in Elixir being harder to read for a newcomer. I don't think they
  match Wrapsher's other syntax constructs very well, and since it
  has method chaining, that's pretty clear in terms of transformations,
  it just doesn't end with the variable being assigned, if the intent
  is a binding.

