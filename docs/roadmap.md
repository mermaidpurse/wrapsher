# ROADMAP

## Issues

- Global variables must be protectable, which probably means
  some kind of file scoping or override assignment so that
  module settings can work. It can cause very very strange
  things to re-assign `list` to a different type for
  example.

## MVP

- Implement module _init(), cohere with **test** module
- Implement/document throw/catch error handling
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
