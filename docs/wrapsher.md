# Wrapsher

Wrapsher is a programming language which compiles to POSIX
sh-compliant shell code. The resulting shell scripts can be run on any
system with a POSIX-compliant `sh`.

The core language is implemented in
[pure POSIX shell](https://pubs.opengroup.org/onlinepubs/9799919799/)
with no external dependencies. This means that any external
dependencies, including commands that are often built-ins (but aren't
required by POSIX to be built-in), are only available in optional modules.

Note that `io` is one of these optional modules, because it requires
commands like `echo` and `printf`, which are not guaranteed by POSIX
to be built-in. Wrapsher calls these commands `external` because they
aren't required to be built-in; in reality, most POSIX-compliant
shells do build these in, so requiring them doesn't actually activate
the `external` feature.

## Status

Wrapsher is pre-alpha software, and not feature-complete.

## Getting Started -- The Basics

The Wrapsher build tool, `wrapsher`, is written in Ruby. But the resulting
compiled program is portable pure `sh`, though, and neither `wrapsher`
nor Ruby are required to run any compiled Wrapsher program--it's standalone,
and requires no dependencies (except for external commands, for which it
will cleanly throw an error if not present).

Wrapsher source code files conventionally have a `.wsh` file extension.

### Installing Wrapsher

Use `gem install wrapsher` or similar invocation to install the **wrapsher**
tool in a supported Ruby version.

### Hello, World

The following is Wrapsher's hello world:

```wrapsher
use module io

int main(list args) {
  io.println("Hello, world")
}
```

Wrapsher programs always have a `main` function as an entry point. The return
value of this function is the program's exit code.

Wrapsher automatically maps command-line arguments to the `main` function's
signature, so the `main` function must accept a list (of strings).

Create a file `hello.wsh` and run `wrapsher compile hello.wsh`. This
will produce an output file `hello`, which starts with `#!/bin/sh` and
contains shell code.

You'll see that one of Wrapsher's design goals is explicitly _not_ to
produce readable or maintainable shell scripts--they are intended to
be opaque, and maintained as Wrapsher programs only. Wrapsher compiles
to a kind of shell-based assembly language which is (intended to be)
safe and correct but isn't terribly readable.

## Language

### Syntax

Top-level statements in Wrapsher can be:

- A `use` statement which enables or incorporates dependencies,
  features, constraints or variables:
    - <code>use external _command_</code>: specifies an external command which is
      required.  At runtime, if the command is found to be built-in
      (e.g., `printf`, usually), it doesn't trigger an `external`
      requirement. If it's not builtin, it does; and the program will
      need to `use feature external` to allow this constraint.
    - <code>use feature _feature_</code>: indicate that the program
      uses or permits the named feature. For example, a program isn't
      allowed to shell out to an external dependency without enabling
      the `external` feature, to indicate the program might need to
      shell out.
    - <code>use module _module_</code>: During compilation, find and
      load the named module in the module search location(s). Note
      that the **core** module is always implicitly included.
    - <code>use global _variable_ _initial\_value_</code>: Introduce
      a new global variable named _variable_ with the specified
      _initial\_value_. The value can be a scalar literal, but not
      a collection.
- A `meta` statement providing metadata:
    - `meta version`: the module or program version
    - `meta source`: the source URL
    - `meta author`: the author
    - `meta doc`: help documentation for the module or program.
      top-level (not in a `module`), this is used as help text in
      the standard option processing. See [Documentation Style](style.md)
      for more.
- A `module` statement which defines the program as a loadable module,
  which can be loaded in other programs with a `use` statement, as well
  as the function namespace. See [Modules and Types](./modules-types.md)
  for more on module and type code organization.
- A function definiton of the form: <code>_type_ _function_(_argument\_type_ _argument\_name_) { ... }</code>,
  for example:
    ```wrapsher
    int main(list args) {
       return 0
    }
    ```
    - In the above definition, we are saying:
        - The `main` function returns an `int` and accepts a list
          of arguments named `args`.
    - Functions can be called as methods (see
      [Functions](./functions.md#receiver-syntax)), which is just
      syntactic sugar for allowing the method "receiver" to be passed
      as the function's first argument, when called.
- A type definition of the form <code>type _typename_
  _store\_type_</code> or <code>type _typename_ _struct_spec_.
  This declares a new user-defined named type,
  based on _store\_type_ or the _struct\_spec_.
  Note that _store\_type_ is just used as
  storage here, enabling the safe cast back and forth between the two;
  this is not any form of inheritance. See [Modules and
  Types](./modules-types.md) for how to implement a type.

Throughout, comments introduced with a pound character (`#`)
are ignored.

A block is a list of expressions (separated by newlines or
semicolons (`;`) and enclosed by curly braces (`{ }`). All
expressions have values, and the value of the last expression is the
value of the block. The following are expressions that can be used:

- A variable assignment of the form <code>_var_ = _expression_</code>.
- A function call of the form <code>_function_(_arguments_)</code> or
  <code>_receiver_._function_(_arguments_)</code>. The method syntax
  with a _receiver_ is just syntactic sugar for placing the first
  argument outside of the regular function list. For example, you can
  call `io.println('foo')` or `println(io, 'foo')`; or
  `mystring.length()` `length(mystring)` equivalently. This also
  allows many function calls to be chained together.  See
  [Functions](./functions.md) for more.
- A shellcode expression of the form <code>shell _string_</code>. The
  _string_ is included inline in the compiled code. Note that just
  as when directly accessing other programming language internals, _this
  is unsafe_ because Wrapsher does not check this code for types or
  POSIX-compliance, or compliance with its standards for external
  dependency management. This should generally only be used in the
  core module. The value of the expression depends on the code in the
  expression conforming correctly to Wrapsher's internal calling
  conventions. See [Internals](./internals.md) for more.
- Certain block expressions like `if` and `try`/`catch`.
- A while loop of the form <code>while _condition_ _block_</code>.
  Within loops, block control keywords `continue` and `break`
  can be used to skip parts of or exit the loop.
- The `return` keyword to return immediately from the function.
- Boolean expressions, using the comparison operators `==`,
  `!=`, `>`, `>=`, `<`, `<=`; and the boolean operators `not`, `and`
  and `or`. See [Operators](#operators) for more.
- Arithmetic expressions, using the arithmetic operators `+`, `-`,
  `*`, `/` and `%`, possibly grouped using parens `(` and `)`.
- Anonymous function definition using the syntax <code>_type_ fun
  (_arguments_) _block_</code>. Anonymous functions are real values
  that can be passed to other functions, assigned to variables, and
  called using the <code>.call().with(_arguments_)</code> functions.
  See [Functions](./functions.md) for more.

Block expressions accept blocks:

- <code>if _expression_ _block_</code>: evaluates the boolean expression
  (that is, an expression returning a `bool`) and,
  if true, executes the provided block.
- <code>if _expression_ _block_ else _block_</code>: evaluates the `bool` _expression_
  and, if true, executes the provided block. If false, executes
  the `else` block.
- <code>if _expression_ _block_ else if _expression_ _block_ ...</code>:
  you can chain `if`, `else if` blocks in this way to avoid nesting
  the blocks.
- <code>try _block_ catch _var_ _block_</code>: executes the first block.
  If any errors are raised, assign the error to the _var_ and execute
  the catch block.
- <code>while _expression_ _block_</code>: evaluates the `bool` _expression_
  and, as long as it's true, loops through the _block_. Inside the
  block, `continue` can be used to skip to the next iteration; `break`
  to exit the loop.

#### Operators

Boolean expressions evaluate to a value of the `bool` type. They are
syntactic sugar for certain functions when implemented by types
(operator overloading):

- `==`, `<`, `<=`, `>`, `>=`: compares two items.
- `and`, `not`, `or`: combines two boolean expressions.
- `(`, `)`: groups expressions.

Arithmetic expressions are similar to Boolean expressions: they are
syntactic sugar for arithmetic functions.

- `+`, `-`, `*`, `/`, `%`: performs addition, subtraction, multiplication,
  division and modulus.
- `(`, `)`: groups expressions.

All operators in these expressions are just syntactic sugar for function
calls. This means that any type can be included in the operator expression
as long as the matching function is implemented against it. Note that
since functions are dispatched according to the type of their first argument,
it will fail if the second argument is not of the correct (usually matching)
type. However, a properly-implemented function can accept an `any` argument
as its second argument, if desired (possibly doing type assertions to check
that the type of the argument is suitable).

Some operators are implemented in terms of other operators, like `!=`, which
doesn't require implementing an `neq()` function or similar, but negates
the result of the `eq()` function.

Any type can implement these functions and be used in the corresponding
expressions. Note that if implementing comparison operators, if you don't
return `bool`s then that could make your syntax quite confusing: resist
the urge to be too clever with operator overloading.

##### Operator Precedence

The operators are grouped into categories of equal precedence, within
each category, precedence is left-to-right. The following priority
order describes the categories:

1. Parens
2. Boolean not
3. Subscript
4. Arithmetic (secondary)
5. Arithmetic (primary)
6. Pair
7. Comparison
8. Boolean

The following lists the operators and their builtin implementations

##### Subscript Operator

The subscript operator `[` is syntactic sugar for the `at()`
function. Any type can be subscripted if it implements this
function. The builtin `string`, `list` and `map` implement
`at()` and can be subscripted in this way.

```wrapsher
string at(string s, int i) { }
any at(list l, int i) { }
any at(map m, any k) { }
```

##### Pair Operator

The pair operator `:` is used to construct a `pair` consisting
of a key and a value. Any type can be used as a key and value.
It's syntactic sugar for the `from_kv` function:

```wrapsher
pair from_kv(type/pair t, any k, any v) { }
```

##### Arithmetic Operators

| Operator   | Function   | Precedence           |
| ---------- | ---------- | -------------------- |
| `*`        | `times()`  | secondary (higher)   |
| `/`        | `div()`    | secondary (higher)   |
| `%`        | `mod()`    | secondary (higher)   |
| `+`        | `plus()`   | primary (lower)      |
| `-`        | `minus()`  | primary (lower)      |

```wrapsher
int times(int i, int j) { } # multiplication
int div(int i, int j) { }   # division
int mod(int i, int j) { }   # modulus
int plus(int i, int j) { }  # addition
int minus(int i, int j) { } # subtraction

string plus(string s, string o) { } # concatenation of strings
list plus(list l, list o) { }       # concatenation of lists
```

##### Comparison Operators

| Operator   | Function   | Precedence              |
| ---------- | ---------- | ----------------------- |
| `==`       | `eq()`     | comparison (even lower) |
| `!=`       | `not eq()` | comparison (even lower) |
| `>`        | `gt()`     | comparison (even lower) |
| `<`        | `lt()`     | comparison (even lower) |
| `>=`       | `not lt()` | comparison (even lower) |
| `<=`       | `not gt()` | comparison (even lower) |

```wrapsher
any eq(any i, any o) { }  # equality of internal representation

bool eq(int i, int j) { } # equality
bool gt(int i, int j) { } # greater than
bool lt(int i, int j) { } # less than

bool eq(string s, string o) { }   # text equality
bool gt(string s, string o) { }   # lexical greater than
bool lt(string s, string o) { }   # lexical less than

bool eq(list l, list o) { }       # order-dependent equality of each element

bool eq(map m, map o) { }         # equality of each pair
```

##### Boolean Operators

| Operator   | Function   | Precedence            |
| ---------- | ---------- | --------------------- |
| `not`, `!` | `not()`    | boolean not (highest) |
| `and`      | `and()`    | boolean (lowest)      |
| `or`       | `or()`     | boolean (lowest)      |

```wrapsher
bool not(bool p)              # logical negation
bool and(bool p, bool q)      # logical AND
bool or(bool p, bool q)       # logical OR
```
  
#### Types and Values

The core language (module **core**) implements the following
builtin types. Note that all types have a zero value and are not
nullable. Type conversion functions (e.g., `int as_int(string
s)`) must be used to read types from input strings or implement
an optional value.


| Type     | Zero                    | Example literal values         |
| -------- | ----------------------- | ------------------------------ |
| `bool`   | `false`                 | `true`, `false`                |
| `int`    | `0`                     | `0`, `99`, `-22`               |
| `string` | `''`                    | `'bob'`, `'café'`              |
| `list`   | `[]`                    | `['one', 2, false, [0, 1, 2]]` |
| `pair`   | `false: false`          | `'one': 1`                     |
| `map`    | `[:]`                   | `['one': 1, 'two': 2]`         |
| `fun`    | `bool fun () { false }` | `bool fun (int i) { i == 0 }`  |

All types implement the following functions or use the generic `any` equivalent:

```wrapsher
my_cool_type new(type/my_cool_type) { }
string to_string(my_cool_type i) { }
string quote(my_cool_type i) { }
```

The `new()` function takes no arguments other than the type
variable (e.g., `bool` or `list`) and returns a new zero value.
The `to_string()` function returns a "nice"
visual representation of the value, which is not intended to
necessarily be completely accurate. The `quote()` function
returns a "literal equivalent" that could be included in a
wrapsher program to define the value.

Each of these builtin types has a way of writing literal values in
that type.

##### `bool`

The only valid values for a `bool` are `true` and `false`. Values
of other types (such as `0`, `''`, `[]`) are never implicitly
converted to `bool`, you must check explicitly (e.g., with `val == 0`,
`val == ''` or `val == []` or `val.len() == 0`).

##### `int`

Integers can be written as a series of decimal digits 0-9. C-style
numbers in an alternative base (e.g. `0x...` or `0`) are not
supported.

Note that floats are not built in the core because they are not built
in to a POSIX shell. See the [**math**](./wsh/math.wsh) module for
floating point arithmetic.

##### `string`

String literals can be single-quoted in single quotation marks (with
internal quotation mark characters `'` escaped with a backslash `\`)
is the literal value of of the string.

The other syntax that is supported are triple-quoted strings, which
begin and end with three quotation marks `'''`.

Note that there are no such things as double-quoted strings in
Wrapsher, nor variable interpolation.[^1] Within a single-quoted string,
any character preceded by a backslash (`\`) is equivalent to its
literal value; there are no special escapes that produce special
characters: a backslash always means the same thing (make the next
character literal). This means the string `'\n'` is equal to
`'n'`. To embed newlines in single-quoted strings, you need to
actually embed the newline, not use `\n`.[^2]

[^1]: Possibly, a future version of wrapsher could support interpolated
  strings which are double-quoted or quoted with backticks.

[^2]: Yes, this is awkward, and at least a character-expanding function
  or syntax is planned.

Strings can be subscripted with the `[` operator as this is syntactic
sugar for `string at(string s, any i)`.

- `int length(string s)`
- `bool has(string s, string search)`
- `int index(string s, string search)`
- `string slice(string s, int i, int len)`
- `string set(string s, int i, string s)`
- `list split(string s, string c)`
- `string replace(string s, string c, string r)`
- `string ltrim(string s, string x)`
- `string rtrim(string s, string x)`
- `string trim(string s, string x)`

##### `list`

Lists are arbitrary-length lists of any type of element (including
lists, maps, user-defined types or other collections).

An list literal is written with enclosing square brackets `[` and `]`
with a comma-separated list of values. The members of a list do not
need to agree on type (you can implement a type which does have this
characteristic, though).

Lists can be subscripted like strings: `mylist[n]` is syntactic sugar
for `mylist.at(n)`.

- `bool has(list l, any e)`
- `int index(list l, any e)`
- `int length(list l)`
- `any head(list l)`
- `any tail(list l)`
- `list set(list l, int i, any e)`
- `list push(list l, any e)`
- `list map(list l, fun f)`
- `bool eq(list l, list otherlist)`
- `bool any(list l, fun f)`
- `bool all(list l, fun f)`

##### `pair`

A pair is a couple (i.e., a 2-tuple), or a single association between
a key and a value. The key and value can be of any type. It is
written literally as <code>_key_: _value_</code>.

- `pair new(type/pair)`
- `any key(pair p)`
- `any value(pair p)`

##### `map`

A map is an associative array indexed by any type of key. Like lists
and strings, it can be subscripted using the `[]` operator: `m[key]`
is syntactic sugar for `m.at(key)`. Maps are written as a list of `pair`s.

- `bool has(map m, any k)`
- `any index(map m, any v)`
- `map set(map m, pair p)`
- `map slice(map m, list l)`
- `map map(map m, fun f)`
- `pair head(map m)`
- `map tail(map m)`
- `int length(map m)`

Like lists, map literals are written in square brackets `[` and `]`.
Within the brackets is a list of pairs. The fact that all members
of a list literal are pairs is what signals that it is a map to
the compiler; if they aren't, then you will get a list instead
(a heterogeneous list).

For example, the following is a map:

```wrapsher
m = [
  'id': 2992,
  'name': 'Harold'
]

m['id'] == 2992
```

While the following is a list (of which one element is pair):

```wrapsher
l = [
  2992,
  'name': 'Harold'
]

try { l['id'] } catch e { e.has("expected an 'int'") }
try { l['name'] } catch e { e.has("expected an 'int'") }
l[0] == 2992
l[1] == 'name': 'Harold'
l[1].key() == 'name'
```

An empty map is denoted by `[:]`.

##### `any`

In some cases, a function may return any type of value, represented
by the `any` type, or accept one. This usually represents a list
element or map value.

A function can accept an argument of any value, as well. In this
case, the function may have to do its own type check using
<code>is_a(_type_)</code> or <code>assert(_type_)</code>.

##### `fun`

An anonymous function item. These are formed by expressions
of the form <code><i>type</i> fun (<i>argument_list</i>)</code>.
The argument list of types and variable names is the same as
in function definitions.

The result of the expression is of the type `fun`, on which you
can use the `call()` function. The return value of `call()`
is a value you can use the `with()` function on to execute
the function according to its type signature.

```wrapsher
f = bool fun (int i) { i % 2 == 0 }
f.call().with(2) == true
f.call().with(1) == false

l1 = [0, 1, 2, 3, 4]
l2 = [2, 4, 6, 8]
# All evens
l1.all(bool fun (int i) { i % 2 == 0 }) == false
l2.all(bool fun (int i) { i % 2 == 0 }) == true
```

Note that the `list` functions, in combination with `fun`
items, make for a powerful way to express iteration.

`fun` items are closures, and capture local variables in
their context. This allows you to do things like:

```wrapsher
factor = 10
[10, 15, 20, 25, 30].select(bool fun (int i) { i % factor == 0 }) == [10, 20, 30]
```

#### Structs

A struct is declared by providing a map of member names
and types to the `type` definition. The resulting type is
implemented as a **list** and standard accessor methods are
provided that operato on the type: a constructor, a
convenience constructor `from_map()`, getters and setters
`to_string()` and `quote()` and `to_map()`.

The struct specifier consists of pairs whose key is a string that is
the member name, and whose value is a type. Like Wrapsher's other
immutable collection types, mutating a struct means assigning a new
struct to something.

Struct members can be of any type, except that directly recursive
definitions are not possible, because Wrapsher does not have null
values to represent optionality. Make such members a list or map
instead. When of type **map**, the setter accepts a whole map to
replace the member, or a pair, and sets just that key in the map.

Example for a hypothetical **employee** type.

```wrapsher
type employee [
  'name': string,
  'age': int,
  'is_contractor': bool,
  'managed_by': list
]

m = employee.new()        # zero value for all members
m = e.set_name('Glinda')
m = e.set_age(53)

e = employee.new()
e = e.set_name('Herb')
e = e.set_age(48)
e = e.set_managed_by(e.managed_by().push(m))

e.managed_by().name() == 'Glinda'
m.to_string() == '''
[
  name: Glinda,
  age: 53,
  is_contractor: false,
  managed_by: []
]
'''
```

You're free to implement any other methods you wish against the
type, of course.

### Variables

Wrapsher has no separate variable declaration syntax, and variables
have no types (values have types, not variables). Data in Wrapsher is
immutable, but variables are rebindable, so when you update a value,
you need to assign the new value. You can assign the new value to the
same variable. This is how you make "updates" to collections, for
example:

```wrapsher
s = 'hello'
s.set(0, 'H')
s == 'hello'
```

```wrapsher
s = 'hello'
s = s.set(0, 'H')
s == 'Hello'
```

Variables are created upon initial assignment, and are cleaned up at
the end of the function they were assigned in. Only local variables
are created in this way. Variables that are captured by a closure
exist inside that closure when called.

Global variables exist but they are not created by top-level
assignments. They are only created through special statements like
`module`, `type` and `use global`. They are referenced just like other
variables and in fact are rebindable (this is how "mutable" global
objects like module settings can be implemented):

```wrapsher
module file

bool is_syncio(module/file m) {
  m._as(map)['synchronous']
}

bool set_is_syncio(module/file m, bool p) {
  file = m._as(map).set('synchronous': p)._as(typeof(m))
}
```

### Errors

Wrapsher discourages the use of "in-band" error signaling requiring
error checks (for example, returning a zero, invalid or null value and
expecting that this will signal an error). Use the keyword `throw` to
throw an error. The argument to `throw` is then used to prevent
further execution. Uncaught errors bubble all the way up to the
top-level and the program panics.

You can catch errors using a <code>try { } catch _var_ { }</code>
block. The _var_ variable is set to the error inside the `catch`
block. If you want to test for error type or condition, use `if`
inside the `catch` block.  You can re-throw the error explicitly using
`throw` again, or you can ignore it.

```wrapsher
int div(int i, int j) {
  if j < 0 {
    throw 'Division by 0'
  }
}
```

```wrapsher
bool process_file(string filename) {
  try {
    f = file.open(filename)
  } catch e {
    if e.message().has('file not found') {
      false
    } else {
      throw e
    }
  }
}
```

As of right now, errors are not rich--they are not intended for
control flow. Errors are a special builtin type: their `to_string()`
method prints the call stack in addition to the message; messages are
intended to be examined as text.

In Wrapsher, it's idiomatic to pre-check operations that might fail
if there is a valid alternative processing path. Error catching
is primarily for cleanup and friendly shutdown rather than control
flow.

### Loops

Wrapsher has `while` loops of the form <code>while _condition_ _block_</code>.
It evaluates the boolean expression in _condition_, and if true, executes
the block; then it repeats until the expression returns `false`. Inside
the loop, the `break` and `continue` keywords can be used to exit
the loop or skip to the next iteration, respectively.

Note that anonymous functions and list functions like `map()`,
provide powerful ways to iterate over a list.

### Programs vs. Modules - `main`

A program is simply the file that the Wrapsher compiler compiles,
producing a target. Wrapsher creates the "glue" code that arranges for
the `main` function to receive the command arguments. By convention,
the program contains no `module` declarations, while modules have
exactly one.

A "module" is a Wrapsher file that is included during compilation
as a result of a <code>use module _module_</code> statement. The compiler
searches for the module in its module include path--a file named
<code>_module_.wsh</code>--and includes its compiled form in the program.

The `main` function in a command must return an `int`. Further, it
must accept a list of arguments (they are strings).

See [Modules and Types](./modules-types.md) for more.

### Testing

Wrapsher includes a TAP-compatible test framework in the
[**test**](./wsh/test.wsh) module.  Consult the module documentation
for usage information.

### External Dependencies

Remember that Wrapsher's primary use case is being able to run your
program _without configuration or bootstrapping_ on any system with
a POSIX `sh`. But it's also true that to do anything useful--especially
in the configuration management or bootstrapping arena--you must,
by necessity, do things that are platform-specific.

Wrapsher allows you to declare a specific dependency on external
commands (including frequently-used ones like `sed` and `awk`) so that
the users of a program can decide if it's acceptable or not, depending
on the platform. You do this with the `use external` statement.

When encountering <code>use external _command_</code>, Wrapsher determines:
- If the command is present; if not, it throws an error (which is fatal)
- If the command is builtin; if not, it signals that the `external` feature
  is required.

Program authors can declare whether external commands are acceptable to their
program by the `use feature external` statement. If this statement is
present, then external commands are allowed. If not, then it is not allowed,
and if a `use external` command is discovered that is not built-in,
a fatal error is produced. The `use feature` statement is only valid
in programs, not modules.

### Standard Library

The folllowing modules comprise the standard library:

| Module | Description | Status |
| :----- | :---------- | :----- |
| [**core**](./wsh/core.wsh.md) | Core functions and builtin types--always included | pre-alpha |
| [**io**](./wsh/io.wsh.md) | Basic I/O based on `echo` and `printf` | pre-alpha |
| [**test**](./wsh/test.wsh.md) | Test framework | pre-alpha |
| [**math**](./wsh/math.wsh.md) | Floats and math functions based on `bc` | **UNIMPLEMENTED** |
| [**sys**](./wsh/sys.wsh.md) | System platform | **UNIMPLEMENTED** |
| [**optparse**](./wsh/optparse.wsh.md) | Parse command-line options | **UNIMPLEMENTED** |
| [**crypto**](./wsh/crypto.wsh.md) | Cryptographic operations based on `openssl` | **UNIMPLEMENTED** |
| [**http**](./wsh/http.wsh.md) | HTTP communication based on `curl` | **UNIMPLEMENTED** |
| [**json**](./wsh/json.wsh.md) | JSON handling based on `jq` | **UNIMPLEMENTED** |

---

> <sub>Copyright (c) 2025 Mermaidpurse
> [MPL-2.0](https://www.mozilla.org/MPL/2.0/) (code)
> [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) (docs)</sub>
