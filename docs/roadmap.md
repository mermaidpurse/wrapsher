# ROADMAP

## Issues

- Global variables should be protectable, which probably means some
  kind of file scoping or override assignment so that module settings
  can work (in other words, you should be able to assign a global
  "when you really mean to"). But it can cause very strange
  things to re-assign `list` to a different type for example.
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

- Syntax highlighting, editor mode
  - Emacs mode: second } doesn't indent right (it's indented one level too far)
- Implement module init(), cohere with **test** module (probably
  where externals checks happen).
- Implement externals/system() or similar (env is a slight prototype)
- Reimplement test framework with real expectation types.
- Github actions for testing (strong preference to write these
  in wrapsher)
- Implement docs
- Implement versions, version constraints (compiler and modules)
- Implement for loop
- Implement rest of standard functions in the core module

## Next Steps

- stdlib modules
- improve test framework
- better syntax errors (parselet's errors are kind of horrendous)
