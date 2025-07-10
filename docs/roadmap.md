# ROADMAP

## Issues

- Local variables must be tracked by the compiler (probably
  with a list in `tables`) so that variable capture can
  occur in closures (using a map, likely)
- Once that is the case, the compiler can do the variable
  cleanup
- The pair operator's precedence is wrong, it should bind tighter
  than everything but boolean not (e.g. `x == k: v` current means
  `false: v` and it should mean `x.eq(k: v)`.
- Need negative ints
- You can't chain operators of the same precedence
- Function signatures must be verified in the compiler to
  avoid stack corruption
- Global variables must be protectable, which probably means
  some kind of file scoping or override assignment so that
  module settings can work. It can cause very very strange
  things to re-assign `list` to a different type for
  example.
- For dispatch, the types `list_string` and `list/string`
  are equivalent. Revise dispatch to figure this out. This
  needs some kind of identifier escaping. Maybe this just needs
  to apply to types, so we could just decide that wrapsher
  types can't have `__` in them, and `/` is represented by
  `__`. So `type list_string` yields `_wshg_list_string`
  and `_wshf_join_list_string`, `type list/string` yields
  `_wshg_list__string` and `_wshf_join_list__string`,
  `type list__string` is illegal, and `type list/_string`
  yields `_wshg_list___string` and `_wshf_join_list___string`.
- Comments can't end the file?
- Only line comments are allowed
- And only at the top-level (not in functions)
- You can't compile the core module because it tries to `use` itself
  due to the wsh preamble.
- Trailing spaces after `}` cause a parse error

## MVP

- Implement pair and map type, literals
- Implement escaped quotes in strings
- Implement module _init(), cohere with **test** module
- Implement/document throw/catch error handling
- Github actions for testing (clean up parser tests)
- Implement docs
- Implement versions, version constraints (compiler and modules)
- Implement while loop maybe? and control keywords maybe?

## Next Steps

- stdlib modules
- improve test framework
- better syntax errors
