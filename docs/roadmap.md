# ROADMAP

## Issues

- Global variables should be protectable, which probably means some
  kind of file scoping or override assignment so that module settings
  can work (in other words, you should be able to assign a global
  "when you really mean to"). But it can cause very strange
  things to re-assign `list` to a different type for example. But

## MVP

- Implement module _init(), cohere with **test** module (probably
  where externals checks happen).
- Implement if-else-if
- Reimplement test framework
- Github actions for testing
- Implement docs
- Implement versions, version constraints (compiler and modules)
- Implement while loop maybe? and control keywords maybe?
- Implement rest of standard functions in the core module

## Next Steps

- stdlib modules
- improve test framework
- better syntax errors
