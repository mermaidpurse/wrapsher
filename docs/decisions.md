# `continue`, `break` and `return`

I feel like these are partly redundant. `break` and `return`
are basically the same thing, aren't they? Can I make `break`
take an argument and `break` from a function or is that too werd?
Maybe I just make them synonyms. I guess the expectation is that
`return` has a different scope, but do I really want to keep track
of these different scopes?

I think I don't want `return` but I need to document how to return.

# Variadic functions?

- No variadic functions (difficult, inconsistent, requires splatting)

# Elsif? Switch-case?

Right now you have to do <code>if _cond_ { } else { if _cond_ { ... }
else { ... } }</code to get multiple case semantics. Nesting the blocks
is a little weird. What about matching multiple cases at once. Switch-case-style
or if-else style or both?

If if-elseif-else style, what's the keyword? Or do we just make the enclosing
block optional, so `else if` works (I like this better than `elsif`, `elif`).

I don't really like switch-case, too much syntax.

# Unions or union types?

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

That could tie nicely into structs

# "First class" structs?

You can manually implement your own struct, but this seems to be such
a common case that maybe something like `type foo struct [id: uuid, name: string]`
should be accepted, and it will generate stuff like:

```
# Pseudocode
foo = wrap(type/foo, list)

list _as_list(foo i) {
  i.unwrap(foo)
}

foo _as_foo(list i) {
  i.wrap(foo)
}
# End pseudocode

foo new() {
  [
    uuid.new(),
    string.new()
  ]
}

uuid id(foo i) {
  i._as_list().at(0)
}

foo set_id(foo i, uuid j) {
  i._as_list().set(0, j)
}

string name(foo i) {
  i._as_list().at(1)
}

foo set_name(foo i, string j) {
  i._as_list().set(1, j)
}
```

## I think I like this:

'stringtwo,andthis,other' / ',' => list split(string s, string d) => ['stringtwo', 'andthis', 'other']

is s / ',' better than s.split(',')? Is this necessary?

## Pairs as their own thing

What if a map really is a list of pairs, and pairs are their own thing, that can be used in function
signatures and stuff. So like

`map map(map m, fun f)`

```
newmap = oldmap.map(fun (pair p) { p.key(): transform(p.value()) }
```

Or even destructuring in the assignment/function call?

key: value = mymap.head()

## Safety and "Namespaces"

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

`use module [version]` is that a thing? Should it be separate, like
in a Wrapsherfile or something that controls compilation? Bundle-style/Go-style
constraints and lockfiles?
## Design Decisions

The [Decisions](./decisions.md) document captures this in more detail,
but 

Here's some things that aren't important/things it shouldn't do:

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
  or be used to implement a shell. A REPL would be nice.

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
  in Elixir being harder to read for a newcomer.

