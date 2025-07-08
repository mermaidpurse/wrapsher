# Wrapsher

Wrapsher is a programming language which compiles (or transpiles) to
POSIX sh-compliant shell code. The resulting shell scripts can be run
on any system with a POSIX-compliant `sh`.

The core language is implemented in
[pure POSIX shell](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html)
with no external dependencies. This means that any external
dependencies, including commands that are often built-ins (but aren't
required by POSIX to be built-in), are only available in optional modules.

Note that `io` is one of these optional modules, because it requires
commands like `echo` and `printf`. Wrapsher calls these commands
`external` because they aren't required to be built-in; in reality, most
POSIX-compliant shells do build these in, so requiring them doesn't
actually activate the `external` feature.

## Status

Wrapsher is pre-alpha software.

## Getting Started -- The Basics

The Wrapsher build tool, `wrapsher`, is written in Ruby. The result is
portable pure `sh`, though, and neither `wrapsher` nor Ruby are required
to run any compiled Wrapsher program.

Wrapsher source code files conventionally have a `.wsh` file extension.

### Installing Wrapsher

Use `gem install wrapsher` or similar invocation to install the **wrapsher**
tool in a supported Ruby version.

### Hello, World

The following is Wrapsher's hello world:

```
use module io

int main(list args) {
  io.println("Hello, world")
}
```

Wrapsher programs always have a `main` function as an entry point. The return
value of this function is the program's exit code.

Wrapsher automatically maps command-line arguments to the `main` function's
signature, so the `main` function must accept a list.

Create a file `hello.wsh` and run `wrapsher compile hello.wsh`. This will
produce an output file `hello`, which starts with `#!/bin/sh` and contains
ugly but straightforward shell code.

You'll see that one of Wrapsher's design goals is explicitly _not_ to
produce readable or maintainable shell scripts--they are intended to
be opaque, and maintained as Wrapsher programs.

## Language

### Syntax

Top-level statements in Wrapsher can be:

- A `use` statement which enables or incorporates dependencies,
  features or constraints:
    - <code>use version _constraint_</code>: specifies a version
      constraint for the compiler version required to compile the
      program. See [Wrapsher versions](#wrapsher-versions) below.
      **UNIMPLEMENTED**
    - <code>use external _command_</code>: specifies an external command which is
      required.  At runtime, if the command is found to be built-in
      (e.g., `printf`, usually), it doesn't trigger an `external`
      requirement. If it's not builtin, it does; and the program will
      need to `use feature external` to allow this constraint.
      **UNIMPLEMENTED**
    - <code>use feature _feature_</code>: indicate that the program requires
      the named feature. For example, a program isn't allowed to shell
      out to an external dependency without enabling the `external`
      feature, to indicate the program might need to shell out.
      **UNIMPLEMENTED**
    - <code>use module _module_</code>: During compilation, find and
      load the named module in the module search location(s). Note
      that the **core** module is always implicitly included.
- A `meta` statement providing metadata which is available to programs
  loading the module (**UNIMPLEMENTED**):
    - `meta version`: the module version
    - `meta source`: the source URL
    - `meta author`: the author
    - `meta docs`: help documentation. When the program is at the
      top-level (not in a `module`), this is used as help text in
      the standard option processing. See [Documentation Style](style.md)
      for more.
- A `module` statement which defines the program as a loadable module,
  which can be loaded in other programs with a `use` statement, as well
  as the function namespace. See [Modules and Types](./modules-types.md)
  for more on module and type code organization.
- A function definiton of the form:
    <pre>
    <i>type</i> <i>name</i>(<i>argument specifiers</i>) <i>block</i>
    </pre> 
    for example:
    ```
    int main(list args) {
       <i>...expressions...</i>
    }
    ```
    - In the above definition, we are saying:
        - The `main` function returns an `int` and accepts a list
          of arguments named `args`.
    - Functions can be called as methods (see [Methods](#methods)),
      which is just syntactic sugar for allowing the method "receiver"
      to be passed as the function's first argument, when called.
- A type definition of the form:
    <pre>
    type <i>typename</i> <i>type</i>
    </pre>
    This declares a new user-defined named type, based on _type_.
    Note that _type_ is used as _storage_ here, this is not any
    form of inheritance. See [Modules and Types](./modules-types.md)
    for how to implement a type.

Throughout, comments introduced with a pound character (`#`)
are ignored **UNIMPLEMENTED**.

A block is a list of expressions enclosed by curly braces. All
expressions have values, and the value of the last expression is the
value of the block. The following are expressions that can be used:

- A variable assignment of the form </code>_var_ = _expression_</code>.
- A function call of the form
  <code>_function_(_arguments_)</code>. Module functions can be
  qualified by module name by prepending the module name and a dot,
  e.g., `io.print`. Type functions can be invoked against the type
  (e.g., `file.open(...)`). Other functions can be invoked against a
  value with the same dot syntax (e.g., `length.to\_string()`
  or `22.to_string()` which are syntactic sugar for `to_string(length)`
  and `to_string(22)`, respectively. See [Functions](./functions.md)
  for more.
- A shellcode expression of the form <code>shell _string_</code>.  The
  _string_ is included inline in the compiled code.  Note that _this
  is unsafe_ because Wrapsher does not check this code for types or
  POSIX-compliance, or compliance with its standards for external
  dependency management.  This is usually used in modules to enable
  direct handling of the `sh` data (Wrapsher's internal sh-friendly
  representation of values) or external commands (for example, in the
  **http** module based on `curl`). The result of the expression is
  dependent on the implementation in the _string_ complying with
  Wrapsher's internal calling conventions. See
  [Internals](./internals.md) for more.
- Certain block expressions like `if` and `shell`.
- Block control keywords `continue` and `break`. **UNIMPLEMENTED**
- Boolean expressions, using the comparison operators `==`,
  `!=`, `>`, `>=`, `<`, `<=`; and the boolean operators `not`, `and`
  and `or`. See [Operators](#operators) for more.
- Arithmetic expressions, using the arithmetic operators `+`, `-`,
  `*`, `/` and `%`, possibly grouped using parens `(` and `)`.
- Anonymous function definition using the syntax <code>fun
  (_arguments_) _block_</code>. Anonymous functions can be assigned
  to a variable and called using the call function. See [Functions](./functions.md)
  for more. **UNIMPLEMENTED**

Block expressions accept blocks:

- <code>if _expression_ _block_</code>: evaluates the boolean expression (
  that is, an expression returning a `bool`) and,
  if true, executes the provided block.
- <code>if _expression_ _block_ else _block_</code>: evaluates the `bool` _expression_
  and, if true, executes the provided block. If false, executes
  the `else` block.
- <code>while _expression_ _block_</code>: evaluates the `bool` _expression_
  and, as long as it's true, executes the _block_. **UNIMPLEMENTED,MAYBE**


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
3. Arithmetic (secondary)
4. Arithmetic (primary)
5. Comparison
6. Boolean

The following lists the operators and their builtin implementations

##### Arithmetic Operators

| Operator   | Function   | Precedence           |
| ---------- | ---------- | -------------------- |
| `*`        | `times()`  | secondary (higher)   |
| `/`        | `div()`    | secondary (higher)   |
| `%`        | `mod()`    | secondary (higher)   |
| `+`        | `plus()`   | primary (lower)      |
| `-`        | `minus()`  | primary (lower)      |

```
int times(int i, int j) # multiplication
int div(int i, int j)   # division
int mod(int i, int j)   # modulus
int plus(int i, int j)  # addition
int minus(int i, int j) # subtraction

list div(string s, any d)       # splitting by substring or interval
string plus(string s, string o) # concatenation of strings
list plus(list l, list o)       # concatenation of lists
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

```
bool eq(int i, int j)    # equality
bool gt(int i, int j)    # greater than
bool lt(int i, int j)    # less than

bool eq(string s, string o)    # text equality
bool gt(string s, string o)    # lexical greater than
bool lt(string s, string o)    # lexical less than

bool eq(list l, list o)        # order-dependent equality of each element

bool eq(map m, map o)          # equality of each pair
```

##### Boolean Operators

| Operator   | Function   | Precedence            |
| ---------- | ---------- | --------------------- |
| `not`      | `not()`    | boolean not (highest) |
| `and`      | `and()`    | boolean (lowest)      |
| `or`       | `or()`     | boolean (lowest)      |

```
bool not(bool p)              # logical negation
bool and(bool p, bool q)      # logical AND
bool or(bool p, bool q)       # logical OR
```
  
#### Types and Values

The core language (module **core**) implements the following
fundamental types. Note that all types have a zero value and are not
nullable. Type conversion functions (e.g., `int as_int(string
s)`) must be used to read types from input strings or implement
an optional value.


| Type     | Zero             | Example literal values         |
| -------- | ---------------- | ------------------------------ |
| `bool`   | `false`          | `true`, `false`                |
| `int`    | `0`              | `0`, `99`, `-22`, `0xa8`       |
| `string` | `''`             | `'bob'`, `'café'`              |
| `list`   | `[]`             | `['one', 2, false, [0, 1, 2]]` |
| `map`    | `[:]`            | `['one': 1, 'two': 2]`         |
| `fun`    | `any fun () {}`  | `bool fun (int i) { i == 0 }` |

Each of these fundamental types has a way of writing literal values
in that type:

##### `bool`

The only valid values for a `bool` are `true` and `false`. Values
of other types (such as `0`, `''`, `[]`) are never implicitly
converted to `bool`, you must check explicitly (e.g., with `val == 0`,
`val == ''` or `val == []` or `val.len() == 0`).

Functions:

- `bool new(type/bool) { false }`
- `bool as_bool(bool p) { p }`
- `bool and(bool p, bool q)`
- `bool not(bool p)`
- `bool or(bool p, bool q)`
- `bool eq(bool p, bool q)`
- `string to_string(bool p)`
- `bool to_bool(string s)`

##### `int`

Integers can be written as a series of decimal digits 0-9.

Note that floats are not built in the core because they are not built
in to a POSIX shell. See the **math** module for a floating point
implementation based on the external dependency `bc` **UNIMPLEMENTED**.

Functions:

- `int new(type/int) { 0 }`
- `int as_int(int i) { i }`
- `int plus(int i, int j)`
- `int minus(int i, int j)`
- `int times(int i, int j)`
- `int div(int i, int j)`
- `int mod(int i, int j)`
- `string to_string(int i)`
- `bool zerop(int i)`
- `int to_int(string s)`

###### `string`

Strings literals can be single-quoted in single quotation marks (with
internal quotation mark characters `'` escaped with a backslash `\`)
is the literal value of of the string.

The other syntax that is supported are triple-quoted strings, which
begin and end with three quotation marks `'''`.

Note that there are no such things as double-quoted strings in
Wrapsher, nor variable interpolation. There are also (currently)
no escape sequences other than `\\` and `\'` **UNIMPLEMENTED**.

Strings can be subscripted with the `[` operator as this is syntactic
sugar for `string at(string s, any i)`.

- `string new(type/string) { '' }`
- `string as_string(string s) { s }`
- `string at(string s, any i)`
- `string ltrim(string s, string x)`
- `string rtrim(string s, string x)`
- `string trim(string s, string x)`
- `bool has(string s, string search)`
- `int index(string s, string search)`
- `string slice(string s, int i, int len)`
- `string set(string s, int i, string s)`
- `string plus(string s, string addon)`
- `string to_string(string s)`
- `int length(strings)`
- `bool zerop(string s)`

##### `list`

Arrays are arbitrary-length lists of any type of element.

An list literal is written with enclosing square brackets `[` and `]`
with a comma-separated list of values. The members of a list do not
need to agree on type (you can implement a type which does have this
characteristic, though).

Arrays can be subscripted like strings: `mylist[n]` is syntactic sugar
for `mylist.at(n)`.

- `list new(type/list) { [] }`
- `list as_list(list l) { l }`
- `any at(list l, int i)`
- `bool has(list l, any e)`
- `int index(list l, any e)`
- `int length(list a)`
- `list slice(list l, int i, int len)`
- `list push(list l, any e)`
- `list set(list l, int i, any e)`
- `list unshift(list l, any e)`
- `list delete(list l, int i)`
- `list plus(list l, list l)`
- `list map(list l, fun f)`
- `any reduce(list l, fun f, any i)`
- `string to_string(list l)`
- `bool any(list l, fun f)`
- `bool all(list l, fun f)`
- `any head(list l)`
- `any tail(list l)`
- `list join(list l, string s)`

##### `map`

A map is an associative array indexed by `string` keys. Like lists
and strings, it can be subscripted using the `[]` operator: `m[key]`
is syntactic sugar for `m.at(key)`.

- `map new(type/map) { [:] }`
- `map as_map(map m) { m }`
- `any at(map m, any k)`
- `bool has(map m, string key)`
- `string index(map m, any e)`
- `map set(map m, string key, any e)`
- `map slice(map m, list l)`
- `string to_string(map m)`
- `map filter(map m, fun f)`
- `map map(map m, fun f)`
- `int length(map m)`

Like lists, map literals are written 

##### `any`

In some cases, a function may return any type of value, represented
by the `any` type, or accept one. This usually represents an list
element or map value.

##### `fun`

An anonymous function item. These are formed by expressions
of the form <code><i>type</i> fun (<i>argument_list</i>)</code>.
The argument list of types and variable names is the same as
in function definitions.

The result of the expression is of the type `fun`, which you
can use the call function:

```
fun/<i>opaque</i> call(fun f)
any with(fun/<i>opaque</i>, ...)
```

Note that in order to call the function, you need to use the
`with` function. The invocation looks like this:

```
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
items, make for a powerful way to express iteration through
recursion.

### Variables

Wrapsher has no separate variable declaration syntax, and variables
have no types. Data in Wrapsher is immutable, but variables are
rebindable, so when you update a value, you need to assign the new
value. You can assign the new value to the same variable. This is
how you make "updates" to collections, for example:

```
s = 'hello'
s.set(0, 'H')
s == 'hello'
```

```
s = 'hello'
s = s.set(0, 'H')
s == 'Hello'
```

Variables are created upon initial assignment, and are cleaned up at the
end of the function they are in. Only local variables are created in this way.

Global variables exist but they are not created by top-level assignments, but
only through special statements like `module`, `type` and `use`. They
are referenced just like other variables and in fact are rebindable (this is
how "mutable" global objects like module settings can be implemented):

```
module file

bool is_syncio(module/file m) {
  m._as_map['synchronous']
}

bool set_is_syncio(module/file m, bool p) {
  file = m._as_map.set('synchronous', p)._as_moduleio()
}
```

### Errors

**UNIMPLEMENTED**

### Loops

**UNIMPLEMENTED**

### Programs vs. Modules - `main`

A program is simply the file that the Wrapsher compiler compiles,
producing a target. Wrapsher creates the "glue" code that arranges for
the `main` function to receive the command arguments. By convention,
the program contains no `module` declarations, while modules have
exactly one.

A "module" is a Wrapsher file that is included during compilation
as a result of a `use module _module_` statement. The compiler
searches for the module in its module include path--a file named
<code>_module_.wsh</code> and includes its compiled form in the program.

The `main` function in a command must return an `int`. Further, it
must accept a list of arguments (they are strings).

You should probably use **optparse** to parse the options.

See [Modules and Types](./modules-types.md) for more.

### Testing

Wrapsher includes a TAP-compatible test framework in the **test** module.

### External Dependencies

**UNIMPLEMENTED**

Remember that Wrapsher's primary use case is being able to run your
program _without configuration or bootstrapping_ on any system with
a POSIX `sh`. But it's also true that to do anything useful--especially
in the configuration management or bootstrapping arena--you must,
by necessity do things that are platform-specific.

Wrapsher allows you to declare a specific dependency on external
commands (including frequently-used ones like `sed` and `awk`) so
that the users of a program can decide if it's acceptable or not,
depending on the platform. You do this with the `use external` statement.

When encountering <code>use external _command_</code>, Wrapsher determines:
- If the command is present; if not, it throws an error (which is fatal)
- If the command is builtin; if not, it signals that the `external` feature
  is required.

Program authors can declare whether external commands are acceptable to their
program by the `use feature external` statement. If this statement is
present, then external commands are allowed. If not, then it is not allowed,
and if a `use external` command is discovered that is not built-in,
a fatal error is produced.

### Standard Library

The folllowing modules comprise the standard library:

| Module | Description | Status |
| :===== | :========== | :===== |
| [**core**](wsh/core.wsh) | Core functions and fundamental types--always included | pre-alpha |
| [**io**](wsh/io.wsh) | Basic I/O based on `echo` and `printf` | pre-alpha |
| [**test**](wsh/test.wsh) | Test framework | pre-alpha |
| [**math**](wsh/math.wsh) | Floats and math functions based on `bc` | **UNIMPLEMENTED** |
| [**http**](wsh/http.wsh) - HTTP communication based on `curl` | **UNIMPLEMENTED** |
| [**sys**](wsh/sys.wsh)           - System shells and platform | **UNIMPLEMENTED** |
| [**optparse**](wsh/optparse.wsh) - Parse command-line options | **UNIMPLEMENTED** |
