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

## Getting Started -- The Basics

**UNIMPLEMENTED**

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

int main() {
  io.print("Hello, world")
}
```

Wrapsher programs always have a `main` function as an entry point. The return
value of this function is the program's exit code.

Wrapsher automatically maps command-line arguments to the `main` function's
signature, so the `main` function will typically have an empty signature
or accept an array

```
int main(array/string args) {
  io.print("Hello, world")
}
```

or (using the variadic syntactic sugar):

```
int main(string args...) {
  io.print("Hello, world")
}
```

Create a file `hello.wsh` and run `wrapsher compile hello.wsh`. This will
produce an output file `hello`, looking like:

```
#!/bin/sh

# Ugly sh code
```

You'll see that one of Wrapsher's design goals is explicitly _not_ to
produce readable or maintainable shell scripts--they are intended to
be opaque.

## Language

**UNIMPLEMENTED**

### Syntax

Top-level statements in Wrapsher can be:

- A `use` statement which enables or incorporates dependencies,
  features or constraints:
    - <code>use version _constraint_</code>: specifies a version
      constraint for the compiler version required to compile the
      program. See [Wrapsher versions](#wrapsher-versions) below.
    - <code>use external _command_</code>: specifies an external command which is
      required.  At runtime, if the command is found to be built-in
      (e.g., `printf`, usually), it doesn't trigger an `external`
      requirement. If it's not builtin, it does; and the program will
      need to `use feature external` to allow this constraint.
    - <code>use feature _feature_</code>: indicate that the program requires
      the named feature. For example, a program isn't allowed to shell
      out to an external dependency without enabling the `external`
      feature, to indicate the program might need to shell out.
    - <code>use module _module_</code>: During compilation, find and load the
      named module in the module search location(s).
- A `meta` statement providing metadata which is available to programs
  loading the module:
    - `meta version`: the module version
    - `meta source`: the source URL
    - `meta author`: the author
    - `meta docs`: help documentation. When the program is at the
      top-level (not in a `module`), this is used as help text in
      the standard option processing. See [Documentation Style](style.md)
      for more.
- A `module` statement which defines the program as a loadable module,
  which can be loaded in other programs with a `use` statement, as well
  as the function namespace. Functions defined at the top level as well
  as those in the `core` module can be called without qualification--all
  other functions need the module name mentioned.
- A function definiton of the form:
    <pre>
    <i>type</i> <i>name</i>(<i>argument specifiers</i>) <i>block</i>
    </pre> 
    for example:
    ```
    int main(string args...) {
      # expressions
    }
    ```
    - In the above definition, we are saying:
        - The `main` function returns an `int` and accepts a variadic
          list of arguments that will show up in an array of strings
          named `args`.
    - Functions can be called as methods (see [Methods](#methods)),
      which is just syntactic sugar for allowing the method "receiver"
      to be passed as the function's first argument, when called.
- A type definition of the form:
    <pre>
    type <i>typename</i> <i>type</i>
    </pre>
    This declares a new user-defined named type, based on _type_.
    Note that _type_ is used as _storage_ here, this is not any
    form of inheritance. It merely means that functions that
    accept it can cast it into the fundamental type to access
    it as that type (usually used only for the type's most
    low-level implementation).

A block is a list of expressions enclosed by curly braces. All
expressions have values, and the value of the last expression is the
value of the block. The following are expressions that can be used:

- A variable assignment of the form </code>_var_ = _expression_</code>.
- A function call of the form <code>_function_(_arguments_)</code>. Functions can
  be qualified by module name (functions in the **core** module
  don't need it) by prepending the module name and a dot, e.g.,
  `io.print`, or invoked against a value with the same dot syntax
  (e.g., <code>_var_.to_string()</code>, which, in the example case that _var_
  has a value of type `int`, is syntactic sugar for `to_string(var)`).
  See [Methods](#methods) for more.
- Certain block expressions like `if` and `sh`.
- Block control keywords `continue` and `break`.
- Boolean expressions.
- Arithmetic expressions.
- Anonymous function definition.

Block expressions accept block(s):

- <code>if _expression_ _block_</code>: evaluates the `bool` expression and,
  if true, executes the provided block.
- <code>if _expression_ _block_ else _block_</code>: evaluates the `bool` expression
  and, if true, executes the provided block. If false, executes
  the `else` block.
- <code>sh block_</code>: interprate the expression in the block as raw shell
  code to be inlined into the result. Note that _this is unsafe_ because
  Wrapsher does not check this code for types or POSIX-compliance, or
  compliance with its standards for external dependency management.
  This is usually used in modules to enable direct handling of the
  `sh` data (Wrapsher's internal sh-friendly representation of values)
  or external commands (for example, in the **http** module based on
  `curl`).
- <code>for _var_ in _collection_ _block_</code>: evaluate the _block_ setting
   the variable _var_ in each iteration.
- <code>for (_var_ = _initial_value_; _assignment_ ; _condition_) _block_</code>:
   evaluate the block with _var_ set to an _initial_value_, applying
   the _assignment_ after each iteration to set a new value, while
   _condition_ holds `true`.

Boolean expressions evaluate to a value of the `bool` type. They are
syntactic sugar for certain functions when implemented by types
(operator overloading):

- `==`, `<`, `<=`, `>`, `>=`: compares two items of the same type, if the
  corresponding `<type>_gt` function is implemented; using the
  functions (for example) `int_eq`, `int_lt`, `int_le`, `int_gt`, `int_ge`
  when the operands are integers.
- `and`, `not`, `or`, `xor`: combines two boolean expressions.
- `(`, `)`: groups expressions.

Arithmetic expressions are similar to Boolean expressions: they are
syntactic sugar for addition functions.

- `+`, `-`, `*`, `/`, `%`: performs addition, subtraction, multiplication,
  division and modulus using (for integers) the functions `int_plus`,
  `int_minus`, `int_times`, `int_div` and `int_mod` functions.
- `(`, `)`: groups expressions.

An anonymous function definition takes the form of a return type, the
keyword `fun` and a function signature. For example, you might define
a function and assign it to a variable, or pass it to a conventional
function call:

```
int main(array args) {
  ints = args.map(int fun(string s) { s.to_int() })
}
```

The result in `ints` will be an array of ints that result from calling
the anonymous function on each (`string`) element of the array `args`.

#### Types and Values

The core language (module **core**) implements the following
fundamental types. Note that all types have a zero value and are not
nullable. Type conversion functions (e.g., `int int_from_string(string
s)`) must be used to read types from input strings or implement
an optional value.


| Type     | Zero            | Example literal values         |
| -------- | --------------- | ------------------------------ |
| `bool`   | `false`         | `true`, `false`                |
| `int`    | `0`             | `0`, `99`, `-22`, `0xa8`       |
| `string` | `''`            | `'bob'`, `'café'`              |
| `array`  | `[]`            | `['one', 2, false, [0, 1, 2]]` |
| `map`    | `{}`            | `{ 'one': 1, 'two': 2 }`       |
| `fun`    | `any fun() {}`  | `bool fun(int i) { i == 0 }`   |

Each of these fundamental types has a way of writing literal values
in that type:

##### `bool`

The only valid values for a `bool` are `true` and `false`. Zero values
of other types (such as `0`, `''`, `[]`) are never implicitly
converted to `bool`, you must check explicitly (e.g., with `val == 0`,
`val == ''` or `val == []` or `val.len() == 0` or `val.emptyp()`).

Functions:

- `bool and(bool p, bool q)`
- `bool not(bool p)`
- `bool or(bool p, bool q)`
- `bool xor(bool p, bool q)`
- `string to_string(bool p)`
- `bool zerop(bool p)`
- `bool to_bool(string s)`

##### `int`

Integers can be written as a series of decimal digits 0-9, as a `0`
followed by a series of octal digits 0-7, and as a `0x` followed by
a series of hexadecimal digits 0-9a-f.

Note that floats are not built in the core because they are not built
in to a POSIX shell. See the **math** module for a floating point
implementation based on the external dependency `bc`.

Functions:

- `int plus(int i, int j)`
- `int minus(int i, int j)`
- `int times(int i, int j)`
- `int div(int i, int j)`
- `int mod(int i, int j)`
- `string to_string(int i)`
- `bool zerop(int i)`
- `int to_int(string s)`

###### `string`

Strings are single-quoted in single quotation marks (with internal
quotation mark characters `'` escaped with a backslash `\`) is the
literal value of of the string.

**TODO:** Note that it is an open question whether Wrapsher will
provide string interpolation in double-quoted stringhs or not--it
isn't a priority. You will need to construct strings by hand using the
`+` operator to incorporate variable values for now, and/or use
the **io** module's `sprintf` function.

A string can be subscripted with the `[]` operator that accepts an
integer subscript; for example, `s[2]` is syntactic sugar for
`s.at(2)` (which in turn is syntactic sugar for `at(s, 2)`).

- `string at(string s, int i)`
- `string ltrim(string s, string x)`
- `string rtrim(string s, string x)`
- `string trim(string s, string x)`
- `bool has(string s, string search)`
- `int index(string s, string search)`
- `string slice(string s, int i, int len)`
- `string set(string s, int i, string s)`
- `string plus(string s, string addon)`
- `string times(string s, int i)`
- `string to_string(string s)`
- `int length(strings)`
- `bool zerop(string s)`

##### `array`

Arrays are arbitrary-length arrays of either mixed types or a single
type, accessed by integer subscript.

An array literal is written with enclosing square brackets `[` and `]`
with a comma-separated list of values. The members of an array do not
need to agree on type (you can implement a type which does have this
characteristic, though).

Arrays can be subscripted like strings: `arr[n]` is syntactic sugar
for `arr.at(n)`.

- `any at(array a, int i)`
- `bool has(array a, any e)`
- `int index(array a, any e)`
- `array slice(array a, int i, int len)`
- `array set(array a, int i, any e)`
- `array delete(array a, int i)`
- `array plus(array a, any e)`
- `array filter(array a, fun f)`
- `array map(array a, fun f)`
- `string to_string(array a)`
- `int length(array a)`
- `bool zerop(array a)`

##### `map`

A map is an associative array indexed by `string` keys. Like arrays
and strings, it can be subscripted using the `[]` operator: `m[key]`
is syntactic sugar for `m.at(key)`.

- `any at(map m, string key)`
- `bool has(map m, string key)`
- `string find(map m, any e)`
- `map set(map m, string key, any e)`
- `array slice(map m, array a)`
- `string to_string(map m)`
- `map filter(map m, fun f)`
- `map map(map m, fun f)`
- `int length(map m)`
- `bool zerop(map m)`

##### `any`

In some cases, a function may return any type of value, represented
by the `any` type, or accept one. This usually represents an array
element or map value.

##### `fun`

An anonymous function item.

- `any call(fun f, ...)`
- `string to_string(fun f)`
- `bool zerop(fun f)`

### Methods

Function calls in Wrapsher are polymorphic and there is some syntactic
sugar to make them look like method calls. A function call like this,
with no receiver:

```
add(x, y)
```

Since there's no receiver, Wrapsher looks for a function called
`add` in either the current module or the **core** module that
accepts arguments of `x` and `y`'s type.

This can equivalently be written:

```
x.add(y)
```

This is merely syntactic sugar for the above.

Types are namespaced according to their module: if `x`, in our
example, is a `vector` type declared in the `vector` module,
the equivalent of `x.add(y)` is `vector.add(x, y)`. If not
using the receiver syntax, then you must specify the function's
module.

### User-defined Types

A new type is introduced with a module-level `type` statement, which
just gives the type a name so that it can be used in function signatures,
and generates cast methods to its underlying storage type.

Implementing appropriate functions allow the type's use. Note that
the storage type doesn't have anything to do with functions or methods that
operate with the type: they all have to be implemented; Wrapsher
is not object-oriented.

Note that you may need to worry about Wrapsher's internal
sh-compatible representation of data, so that is briefly discussed
here.

Here are two examples: implementing a `vector` type consisting of a
three-tuple of integers, and a `package` type consisting of
struct-like fields representing an OS package (for example, for
configuration management).

For our vector example, we will basically alias an array.

```
# vectors.wsh
module vector

# Automatically generates array as_array(vector v)
# and vector as_vector(array a)
type vector array

# Callable as vector.new(0, 0, 0)
vector new(int x, int y, int z) {
  # Return origin x, y, z
  # Wrapsher understands this alias
  [x, y, z].as_vector()
}

# Callable as v.x() -- it's a "getter"
int x(vector v) {
  v.as_array()[0]
}

int y(vector v) {
  v.as_array()[1]
}

int z(vector z) {
  v.as_array()[2]
}

# Callable as v.to_string
string to_string(vector v) {
  # We'll need the array
  '(' + v.as_array().to_string().trim('[]') + ')'
}
  
```

```
# showvector.wsh
use module io
use module vector

int main(string args...) {
  x = args[0].to_int()
  y = args[1].to_int()
  z = args[2].to_int()
  v = vector.new(x, y, z)
  io.print(v.to_string)
}
```

And we compile it and run it:

```
$ wrapsher compile showvector.wsh
$ ./showvector 0 22 1
(0, 22, 1)
```

Of course, there are much more interesting things to do with vectors,
so we'll probably implement things like a magnitude function using
the **math** module and so forth.

Like our vector, struct-like types are usually implemented as
arrays, but we'll implement this as a map to show how to do
it:

```
# package.wsh
module package

# Generates package as_package(map m)
# Generates map as_map(package p)
type package map

# Callable as package.new()
package new()
  ({
    'name': '',
    'version': '',
    'installed': false
  }).as_package()
}

package new(string package) {
  name = package.split('-')[0]
  version = package.split('-')[1]
  ({
    'name': name,
    'version': version,
    'installed': false
  }).as_package()
}

# Getters
string name(package p)      { p.as_map()['name'] }
string version(package p)   { p.as_map()['version'] }
bool   installed(package p) { p.as_map()['installed'] }

# Setters
package set_name(package p, string name)         { p.as_map().set('name', name).as_package() }
package set_version(package p, string version)   { p.as_map().set('version', version).as_package() }
package set_installed(package p, bool installed) { p.as_map().set('installed', installed).as_package() }

# A more convenient setter
package install(package p) { p.as_map().set('installed', true).as_package() }
```

Note that Wrapsher is not an object-oriented language and a type does
not "inherit" any functions. You will need to implement all getters
and setters (for now--Wrapsher may be extended at some point, or
a module for constructing and using structs specifically could be
written). This is why values in Wrapsher are usually called "items"
rather than "objects".

You'll also notice something about the compound types: their values
are immutable. In order to update them, you generate a new item.
There is no assignment on dereference (that is, something
like `data['water'] = 'wet'` is not allowed). You must use
accessor functions and assign the result (multiple assignment
_is_ allowed:

```
data = data.set('water', 'wet')
```

### Commands vs. Modules - `main`

A "command" is a Wrapsher file that is not qualified as a `module`
and has a `main` entry point. Note that if `module` is declared in
the file, any `main` function is interpreted as a normal function
and no special processing is applied by the Wrapsher compiler (it
could be called as <code>_module_.main</code> in the normal way.

A "module" is a Wrapsher file that has a `module` declaration.  When
loaded using the `module` statement, the functions and types in the
module are available qualified by the name of the module.

The module namespace is flat--there is no hierarchy of modules.

The `main` function in a command must return an `int`. Further, it
must accept either no arguments (its signature is `int main()`) or an
array.

It's very common to apply the core module's optparse function to the
arguments to `main` (`optresult optparse(optspec spec, array args)`):

```
int main(array args) {
  optspec.from_map({
    'output': {
      'type': string,
      'short': 'O',
      'help': 'Output file'
    },
    'limit': {
      'type': int,
      'short': 'l',
      'help': 'Number of bytes',
      'default': 100
    }
  })

  result = optparse(optspec, args)
  opt = result.opt()
  args = result.args()

  if opt.has('output') {
    output = io.open(opt['output'])
  } else {
    output = io.stdout()
  }

  io.fprintf(io.output, 'limit is %d\n', limit)
}
```

Other option parsing techniques are possible, but we consider it
desirable to be opinionated towards an easy-to-use standard, which
is why this is in the core library.

### External Dependencies

Our **packages** module isn't very interesting without being able
to actually query a package database; and this is where things get
platform-dependent and we can see how Wrapsher handles these kinds
of dependencies.

Remember that Wrapsher's primary use case is being able to run your
program _without configuration or bootstrapping_ on any system with
a POSIX `sh`. But it's also true that to do anything useful--especially
in the configuration management or bootstrapping arena--you must,
by necessity do things that are platform-specific.

Wrapsher allows you to declare a specific dependency on external
commands (including frequently-used ones like `sed` and `awk`) so
that the users of a program can decide if it's acceptable or not,
depending on the platform.

Let's extend our **packages** module so that it can run `dkpg` on
Debian systems to see if a package is installed. Note that we're doing
this directly because Wrapsher is in its infancy: there will be a
greatly-expandend **system** module in the future to provide more
help, such as the ability to detect and select different dependencies
depending on the platform. Future enhancements might include auto-detecting
the external dependency based on `system()` invocations.

**TODO:** This examples contains undocumented loop features (`for`,
`break`) and undocumented string functions:

- `array string_lines(string s)`
- `array string_split(string s, string separator)`
- `array string_matches(string s, string pattern)`

```
# packages.wsh
module packages

use external dpkg

use module sys # contains 'type result' and 'result sys.system(string command...)' function

type package map

package new_package() {
  {
    'name': '',
    'version': '',
    'installed': false
  }
}

# additional type constraint
bool check_package(package p) {
  p.len == 3 and p.keys.sort == ['installed', 'name', 'version']
}

package package_from_string(string name) {
  r = sys.system('dpkg -l ' + package)
  if r.exitcode != 0 {
    for line in r.stdout.lines {
      if line.matches('ii*') {
        fields = line.split(' ')
        installed true
        version = fields[2]
        break
      }
    }
  } else {
    installed = false
    version = ''
  }

  {
    'name': name,
    'version': version,
    'installed': false
  }
}

# Getters
string package_name(package p)    { p['name'] }
string package_version(package p) { p['version'] }
bool package_installed(package p) { p['installed'] }

# Setters
string package_install(package p) { p.set('installed', true) }
```

Here we've modified our module so that you provide the package name and
the function using `dpkg -l` to query the package database for the installed
version and sets the appropriate fields accordingly.

### Standard Library

The folllowing modules comprise the standard library:

- [**core**](stdlib/core.wsh) - Core functions and fundamental types, some I/O based on `read` and redirection?
- [**io**](stdlib/io.wsh)     - Basic I/O based on `echo` and `printf`
- [**math**](stdlib/math.wsh) - Floats and math functions based on `bc`
- [**http**](stdlib/http.wsh) - HTTP communication based on `curl`
- [**sys**](stdlib/sys.wsh)   - System shells and platform (or maybe this is core)
- [**test**](stdlib/test.wsh) - Test framework (maybe start with bats-core?)

## Roadmap/TODO

Roughly in priority order:

- Module documentation
- Typed collections (array/string, map/map/int) and
  variadic signatures. Could this be done like `type array/string array`?
- remote modules, modules.wsh? Wrapsherfile?
- funs
- Emacs mode (language server?) and formatter (`wrapsher fmt`)
- Background jobs/parallelism
- JSON (start with `jq`?)
- Syntactical improvements:
    - String interpolation or templating?
    - Array comprehensions
    - Map comprehensions

Maybes:

- Compile-time type checking
