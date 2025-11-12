# Documentation Style

Wrapsher is opinionated about documentation--programs and
modules are expected to be documented using the `meta doc`
metadata statement.

Documentation in source code is written in Markdown. Accompanying
documentation should be written in Markdown as well, and follow
the following conventions:

- The documentation should readable as plain text--minimize
  the use of HTML.
- Most literal code mentioned inline should be set off in code strings using
  backticks (<code>``</code>). When using a metasyntax
  reference (for example, when the name of a variable is
  up to the user and you want to give an example of using
  that variable as an argument to the `io.printf` function,
  typeset the metasyntactic reference in italics: for example,
  <code>io.printf(_format_, _variable_)</code>.
- When showing examples of literal code, use fenced code blocks
  separated by triple-backticks and marke the example
  as Wrapsher code: <code>```wrapsher</code>. Typesetting in
  italics for metasyntactic references is not supported (code
  blocks should contain runnable code) so instead, choose identifiers
  and literals so that it's obvious to the reader they must
  substitute their own value, generally using the words "my cool"
  or the equivalent, like `my_cool_something` or `"My Cool User"`.
- When making reference to the following in prose (not literal
  code examples):
    - Typeset module and type names in **bold**, e.g., "the **io**
      module", "an **int** variable".
    - Typeset other literal identifiers using backticks
      (<code>``</code>), e.g., "as an example of using
       the `use version` constraint...".
     - Typeset variable values and other things that you're referring
       to metasyntactically--that is, where the user must provide a
       value but you want to refer to whatever that value is in prose,
       in italics, e.g. "this allows the **io** module to accept
       _username_ as input".

Avoid too much other markup or formatting.

Avoid redundant documentation, like "--force - Force"; instead,
each option, attribute, function or parameter should come with
a description of its purpose and some indication about how
the user or caller should choose its value or in what circumstance
they will use it.

Module documentation should be written to inform the programmer who is
using and loading the module. Program documentation should be written
to inform the user who is running the command to accomplish a task.
