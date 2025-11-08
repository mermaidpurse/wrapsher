# [Amber](https://amber-lang.com/)

Some of Wrapsher's initial inspiration was a post on Hacker News about
Amber, a language compiled to bash. It seems like a great project,
with a robust parser/compiler implementation that focuses on producing
interpretable bash code that resembles the input language.

In the end, Wrapsher has different goals, so I did a cursory
comparison of some language features, and some commentary on why
Wrapsher is different. Note that as of this writing (while Wrapsher is
not even version `0.1.0`), some of Wrapsher's features are pending,
and so indicated.

| Feature | [Amber 0.4.0](https://docs.amber-lang.com/0.4.0-alpha) | Wrapsher 0.1.0 | Comment |
| :------ | :----------------------------------------------------- | :------------- | :------ |
| Type-checking | optional | mandatory | Wrapsher has an `any` generic which matches all types |
| Scalar types | Text, Num, Bool, Null | string, int, bool | |
| Collection types | Array (1-dimension) | list, map, pair (arbitrarily nested) | |
| User-defined types | no | yes | Wrapsher allows you to define arbitrarily complex types |
| Loops | inifinite loop, for loop | while loop, for[^2] loop | Iterates over any collection |
| Error handling | ignore or manually checked | throw/try/catch | |
| External commands | inlined text substitution | declared dependencies[^2] | Wrapsher is designed to fail early when prerequisites aren't met |
| Code sharing | `import` functions from files | `use module`s | Wrapsher modules are intended to be a full module system[^1] |
| Tests | manually-written | **test** module | |
| Runtime | bash | any POSIX sh | |
| Paradigm | compiled and interpreted; imperative | compiled; multiparadigm | functional, imperative |
| Influence | ECMAScript, bash | C, Python, Lisp | |
| Implementation language | Rust | Ruby | |
| REPL | no | no | |
| IDE Tools | no | Emacs mode, LSP[^2] | |

Wrapsher's intention is to allow you to build "somewhat large" programs and systems, and
to provide the tools (like complex types, error handling, etc.) to get you there safely. It's
also designed to work in "hostile" environments where you're bootstrapping a system, such
as installers and system initializers, and so its intention is to minimize dependency on
specific runtimes like `bash`, and allow you to do the safest thing (and fail immediately)
when critical external dependencies (like `curl` for http) are unavailable, rather than
failing somewhere down the line in executing the program, when the program encounters the
`curl` call.

On the other hand (as of this writing) Amber's parser implementation is clean, robust and
well-implemented, whereas Wrapsher is extremely pre-alpha and full of edge cases and parsing
issues.

[^1]: Although Wrapsher doesn't have module namespaces _per se_, module types and the module
  global value serve as a namespace for most module use cases; in addition to the types
  declared in the module. This allows `io.println`, `file.println` and `myfd.println`
  to coexist and refer to different functions. Amber prepends a pseudo-namespace to certain
  standard libary functions, e.g. `array_contains`, `char_at`, etc.

[^2]: Pending!
