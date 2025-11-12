# ROADMAP

## Issues

- Multiline function calls, or maybe multiline function calls with
  funs, don't seem to work, like `map(\n...fun...\n)`, maybe
  other multiline calls. It works when you break on the `{` and
  `}` for the function call.
- Global variables should be protectable, which probably means some
  kind of file scoping or override assignment so that module settings
  can work (in other words, you should be able to assign a global
  "when you really mean to"). But it can cause very strange
  things to re-assign `list` to a different type for example.
- The local variable check needs to happen during compilation and
  get flagged then, because that's ordered within a context. Right
  now, it checks after fact, so if the local variable was used before
  assignment, it passes.
- Slow startup because all of the header constants are constructed
  with function calls: compiler should produce ref literals. This
  probably means separating parsing and transformation back out and
  testing them separately. Which also means revamping line numbers
  and not being so redundant (I think the compiler can put them all
  in the context arguments to `_wsh_check_return` so we don't
  need all those `_wsh_line=` at all).
- The core module should contain the `env` functionality;
  including core should get you everything that is accessible
  that is required by posix.
- Big files
    - also caused by header constants being set in code rather
      than something terser
    - lots of redundant line numbers (this can just be added
      by the compiler in _wsh_check_return, maybe?)
    - the whole (compiled) module is inlined, when most functions
      could be stripped because they are not referenced.

## MVP

- Github actions for testing (strong preference to write these
  in wrapsher)
- Implement docs
- Implement versions, version constraints (compiler and modules)
- Implement for loop
- Implement rest of standard functions in the core module
    - list methods (`reduce()`, `delete(0)`)

## Longer-term Issues

- The parser is still pretty brittle and subject to edge cases and not
  as useful as it could be due to top-level statements and expressions
  being different. The errors are pretty horrendous, too (the way the
  PEG shows errors can be really unrelated to where the error actually
  occurs).
- There are many inefficiencies that make lots of stuff in Wrapsher
  very slow.  Some of these are unavoidable but a lot of overhead
  could be reduced for some things.

## Next Steps

- stdlib modules
- improve test framework
- better syntax errors (parselet's errors are kind of horrendous)
