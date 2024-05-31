# README

Wrapsher is a shell wrapping language[^1] which takes a
programmer-friendly, typed language and renders (transpiles) it to
[POSIX-compliant sh](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html).

[^1]: The name comes from some munging of "things which wrap a shell",
  "**wrap sh**ell thing**er**" even though what it's doing isn't
  entirely wrapping the shell language.

You can therefore use Wrapsher to write programs that will run on
any[^2] platform (for some value of "any") and, when you need to
bring in modules with external dependencies (like `curl` for
network programming), Wrapsher will help you to define those
dependencies, introspect them and handle them elegantly (namely,
it will fail if the platform doesn't provide something your program
needs, rather than do a garbage thing).

[^2]: The language core will run in any POSIX-compliant shell, but
  you will probably need some non-POSIX utilities like `echo`
  to do literally anything. Most shells actually build these in,
  and Wrapsher will be cognizant to this and friendly about it.

## Inspiration

I took some inspiration from [Amber](https://amber-lang.com/), which I
read about on [HN](https://news.ycombinator.com/item?id=40431835),
and [Ansible](https://www.ansible.com/), an agentless configuration
management system which I've loved to hate and hated to love.

I really liked this idea and the way it allows you to use a
programming language with types to produce bash, a ubiquitous runtime.

The actual implementation here differs (at the time of Wrapsher's
conception) from what I find exciting about the core idea, namely:

- It overuses dependencies like sed and bc, without handling them robustly
  or elegantly (this is very common with "pure shell" solutions of
  every stripe).
- It targets bash rather than POSIX sh, which is more standard (and
  more ubiquitous-er)
- Some of the syntax (`$..$` for commands) isn't to my taste.
- Subshells, pipelines, error handling, etc.
- It seems more closely tied to bash's capabilities than I'd
  like--more ambition could result in a better core language, with
  modules, dependency-handling etc.

One of the design centers for such a language would be implementing
a configuration management or configuration bootstrapping tool--taking
Ansible's notion of an agentless architecture to its extreme, by
implementing an Ansible-like tool in a good programming language
which runs on "any" system (for some value of "any").

## Design and Vision

Here are some things I'd want Wrapsher to be able to do (it's a "wish
list" and subject to constant, opinionated change).

- Have a powerful, terse, elegant, beautiful and close-to-standard syntax.
- Think from the start about modularization and dependency management.
  For example, a dependency on `curl` for network operations should
  be explicit and optional. The core language should rigorously depend
  only on POSIX sh.
- Same for platform dependencies like `/dev/null`.
- User-defined types like structs and stuff.
- Easy error handling. Map the shell's weird exit codes and stdout
  capturing into programmer-friendly exceptions and return values.
- Testing/test framework out of the gate
- A Wrapsher program results in a script runnable (if not readable) in
  an entirely conventional sense.
- Dependencies can be hand-written sh (that is, you can write modules
  in sh instead of Wrapsher if you want).
- Efficient (no forking, subshells or external commands except when
  actually necessary). This might include using certain external commands
  as servers, where possible (in an `expect`-like way). This notion of
  efficiency probably does not necessarily mean speedy--although what
  typically slows shell scripts down are external calls.
- Maybe consider
  [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html)
  to be more reliable than arbitrary ones (e.g., curl).
- Parallelism

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

Things I like in various languages that would be nice to incorporate:

- First-class functions
- Go-like mandatory initialization of typed variables (every type has a "zero value")
  rather than nullability.
- Namespacing
- Easy parallelism of some kind
- `use` as a way to enable a feature or bring in a module--I just like the word
- Algol-ish syntax for popularity (I love Erlang but few people really do. It should look
  kind of like C/Go/everything else).
- Perl-like version constraints (`use version ...`)
- Erlang-like lack of keyword for function definiton (no `def`)
- Set/array/list comprehensions

Some ideas I had that don't seem feasible:

- Pipelines. I do like them in Powershell, I guess I like them in
  Elixir but they seem complicated and I think they actually result
  in Elixir being harder to read for a newcomer.
- Mildly object-oriented method message sending syntax, e.g.
  `var.fun(1)` -> `__type_fun(var, 1)` or something. This
  conflicts with module namespacing, so I think I'll stick with
  this. If you want something object-ish (for now) you'll need
  to do C-style convention where the first argument is `self`
  kind of thing.

## Implementation Notes/Ideas

```
To achieve output using strictly POSIX-mandated built-ins, we can use :, . (dot), break, cd, continue, eval, exec, exit, export, readonly, return, set, shift, times, trap, and unset. However, generating user-visible output strictly with these built-ins is not feasible since they do not handle output directly.
```

In `use module io`, you are permitted to use the following often
built-in commands (but whether `io` requires the feature `external` is
platform-dependent and detected at runtime). See, there are no
strictly POSIX commands that can do I/O: although most shells
implement `echo` and `printf` as built-ins, they aren't required to,
and I'd like the language core to be strictly dependent on a POSIX
shell and nothing else. The `io` module will probably use the
following declarations to indicate its dependency on these tools.

`use external echo`
`use external printf`

The approach I'm taking right now is to transpile to shell with a calling
convention based on:

Values are tagged with their type and type-checked at runtime using generated
shell code, e.g.:

- booleans `bool:true`
- integers `int:8`
- strings `string:one flew over the cuckoo's net`
- array `array/any:<ref> <ref>`, `<ref>`s here are variable names storing the value. Arrays could get renamed and may get
  optional type-checking of elements added.
- map `map/any:key=<ref>`. Maps could get renamed, keys are strings (like in JSON) and values are anything.

Function calls are namespaced into modules and the type of their first
argument. When compiling a file, the functions in that file are not
namespaced:

Wrapsher source (`wrapsher compile frobulate.wsh` -> `frobulate`):
```
# frobulate.wsh
meta description 'frobulate your quibbles'

int main(string args...) {
  arr = []
  for a in args {
    arr = append(arr, toint(a))
  }
  0
}
```

**Q:** Would this be easier to choose a top-level namespace? `main` or something?

`sh` output:

```
# omitting boilerplate

__wsh_string_main() {
  __wsh__error=
  __wsh__loc=frobulate.wsh:4
  __wsh__check_type array/int "${1}" || return 1
  __wsh__error=
  __wsh__loc=frobulate.wsh:5
  __wsh_array_new || return 1
  __wsh__error=
  __wsh__loc=frobulate.wsh:5
  __wsh__loc=frobulate.wsh:6
  for __wsh__ref_a in ${__wsh_arr}
  do
    __wsh__loc=frobulate.wsh:6
    __wsh__deref 'a' || return 1
    __wsh__error=
    __wsh__loc=frobulate.wsh:6
    __wsh_a="${__wsh_result}"
    __wsh__loc=frobulate.wsh:7
    __wsh_string_toint "${__wsh_a}" || return 1
    __wsh__error=
    __wsh__loc=frobulate.wsh:7
    __wsh__arg1="${__wsh__result}"
    __wsh_array_append "${__wsh_arr}" "${__wsh__arg1}" || return 1
    __wsh__error=
    __wsh__loc=frobulate.wsh:7
    __wsh_arr="${__wsh__result}"
  done
  __wsh__loc=frobulate.wsh:8
  __result='int:0'
}

__wsh_string_main "$@" || __wsh__error
```

Internal utility functions (form reserved words that you can't
use for your function, e.g., you can't call a function
`_check_type` because of `__wsh__check_type`):

| `sh` Function | Wrapsher reserved word | Description |
| --- | --- | --- |
| __wsh__check_type | `_check_type` | Checks argument types and sets __wsh__error if they're wrong, returning `1` |

Special shell variables:

| Variable | Wrapsher reserved word | Meaning  |
| --- | --- | --- |
| __wsh__loc | `_loc` variable | Source code location |
| __wsh__result | `_result` variable | Result of latest expression |
| __wsh__error | `_error` variable | Result of latest error |
| __wsh__arg.* | `_arg?` variables | Arguments to the next function call, if expression results |

There's no "return" in `sh`: there's output and exitcodes. Every shell expression
that can fail is postpended with `|| return 1`. This bubbles all the way up
to the main function which has a `||` that (tries to) print the error and
exit 1. Returning 1 from a function is analogous to throwing an exception
and is how Wrapsher handles unrecoverable errors.

Since there's no output in core Wrapsher or POSIX `sh`, calling convention is to
assemble arguments to pass to functions and receive the result in `__wsh__result`.
