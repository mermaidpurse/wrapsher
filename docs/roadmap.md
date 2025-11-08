# ROADMAP

## Issues

- Need `bool assert(any i, any as)` to check type.
- Environment variable injection--we need to clear the environment of
  anything starting with `_wsh` I think
- Emacs mode: second } doesn't indent right (it's indented one level too far)
- CLI: <code>wrapsher _op_ t.wsh</code> doesn't work but `./t.wsh` does
- Compiler error: use unreferenced variable
- Compiler error: redefine function
- Tests for compiler errors (global redefine, etc.)
- Global variables should be protectable, which probably means some
  kind of file scoping or override assignment so that module settings
  can work (in other words, you should be able to assign a global
  "when you really mean to"). But it can cause very strange
  things to re-assign `list` to a different type for example.
- slow startup because all of the header constants are constructed
  with function calls: compiler needs to produce ref literals. This
  probably means separating parsing and transformation back out and
  testing them separately. Which also means revamping line numbers
  and not being so redundant (I think the compiler can put them all
  in the context arguments to `_wsh_check_return` so we don't
  need all those `_wsh_line=` at all).
- the core module should contain the `env` functionality;
  including core should get you everything that is accessible
  that is required by posix.
- Line numbers are missing on some stack frames (maybe all but the
  innermost one)
- Decreased the runtime of `env_test.wsh` from 60 seconds or
  so to 12 seconds, but 12 seconds is still a pretty long total
  time. Need to profile this, I think the proplist-style search
  for maps is expensive (in part because it has to deref twice
  since a pair is a reflist).


## MVP

- Syntax highlighting, editor mode
- Implement module init(), cohere with **test** module (probably
  where externals checks happen).
- Profiler and/or integration with shell profiler
- Implement externals/system() or similar
- Reimplement test framework
- Github actions for testing (strong preference to write these
  in wrapsher)
- Implement docs
- Implement versions, version constraints (compiler and modules)
- Implement for loop
- Implement rest of standard functions in the core module

## Next Steps

- stdlib modules
- improve test framework
- better syntax errors
