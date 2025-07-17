# ROADMAP

## Issues

- Global variables should be protectable, which probably means some
  kind of file scoping or override assignment so that module settings
  can work (in other words, you should be able to assign a global
  "when you really mean to"). But it can cause very strange
  things to re-assign `list` to a different type for example. But
- slow startup because all of the header constants are constructed
  with function calls: compiler needs to produce ref literals. This
  probably means separating parsing and transformation back out and
  testing them separately. Which also means revamping line numbers
  and not being so redundant (I think the compiler can put them all
  in the context arguments to `_wsh_check_return` so we don't
  need all those `_wsh_line=` at all).

## MVP

- Implement return
- Implement if-else-if
- Implement syntax fixes
- Syntax highlighting, editor mode
- Implement module _init(), cohere with **test** module (probably
  where externals checks happen).
- Implement externals/system() or similar
- Reimplement test framework
- Github actions for testing
- Implement docs
- Implement versions, version constraints (compiler and modules)
- Implement for loop
- Implement rest of standard functions in the core module

## Next Steps

- stdlib modules
- improve test framework
- better syntax errors
