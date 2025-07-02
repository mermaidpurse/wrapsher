# Documentation Style

**TODO:** Unimplemented

Wrapsher is opinionated about documentation--programs and
modules are expected to be documented using the `meta docs`
metadata statement.

Documentation in source code is written in Markdown. Accompanying
documentation should be written in Markdown as well, and follow
the following conventions:

- The documentation should readable as plain text--minimize
  the use of HTML.
- Most literal code should be set off in code blocks using
  backticks (<code>``</code>). When using a metasyntax
  reference (for example, when the name of a variable is
  up to the user and you want to give an example of using
  that variable as an argument to the `io.printf` function,
  typeset the metasyntactic reference in italics: for example,
  <code>io.printf(_format_, _variable_)</code>. In Markdown,
  this means using `<code>` or `<pre>` instead of normal
  Markdown syntax.
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

Modules should be written to inform the programmer who is using
and loading the module. Commands should be written to inform
the user who is running the command to accomplish a task.
