# ROADMAP

- Change array to list
- Implement variable scope (look real hard again at whether
  POSIX could have variable scope). This could be a real pain,
  because the variable needs to be looked up at reference to
  see where it is, you can't just assume the function name, because
  global variables have to be a thing.
  It does allow you to decide you can't shadow global variables.
- Implement anonymous functions
- Test harness
- Implement map
- Implement array and map literals and subscript notation
- Implement `type typeof(any i)`, `bool expect(any i, type t)`
- Implement type/subtype expressions in function signatures
- Implement/document throw/catch error handling
- Implement `null assert(any i, type t)` (throws)
- Implement while loop maybe? and control keywords
