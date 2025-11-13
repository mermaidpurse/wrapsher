# Wrapsher is a programming language which compiles to shell

[Wrapsher](./wrapsher.md) is a shell wrapping language[^1] which takes a
programmer-friendly, typed language and compiles it to
[POSIX-compliant sh](https://pubs.opengroup.org/onlinepubs/9799919799/).

[^1]: The name comes from some munging of "things which wrap a shell",
  "**wrap sh**ell thing**er**" even though what it's doing isn't
  entirely wrapping the shell language.

You can therefore use Wrapsher to write programs that will run on
any[^2] platform (for some value of "any") and, when you need to
bring in modules with external dependencies (like `curl` for
network programming), Wrapsher will help you to define those
dependencies, introspect them and handle them elegantly (namely,
it will fail if the platform doesn't provide something your program
needs, rather than do a garbage thing, as shell scripts do).

[^2]: The language core will run in any POSIX-compliant shell, but you
  will probably need some utilities, like `echo`, that are not
  required by the standard to be built in to the shell.  _Most shells_
  actually build these in, and Wrapsher will be cognizant to this and
  friendly about it.

## Use Case: What problems does Wrapsher solve?

_Or: You want to **run** a shell script, but you sure don't want to
**write** one._

Shell code (e.g. bash, but also other Unix-style shells) is notoriously
bad to write programs in:

- Data is unstructured and approximated non-type-safely with strings
- It confuses the notion of output and return values
- It offers no tools for dependency management or code organization
- Error modes are dangerous--it's easy to destroy things by messing
  up quoting and string interpolation, for example
- Malicious actors can use the above to perform command injection
  attacks
- It's (somewhat) hard to test

All these things mean that, in general, you should not write programs
in shell if you can avoid it. Certainly not ones that are
"complex"--whatever that means to you.

So why are shell scripts still so ubiquitous, and why are they used?

Because shell has this killer advantage: **It is nearly ubiquitous**.

Let's say you want to write your "real" logic in Python, or Go, or
some other programming language that is better than shell. If you do,
you then you need to deal with distributing the program and its dependencies,
as well as installation concerns. For example, if using Python, the user needs to
install Python and possibly many dependencies in order to run your
program. If using Go, the executable may be relatively self-contained--
but you still need the user to worry about selecting the proper build
for their architecture, and maybe platform. In fact, it's quite likely
that the tool you use to handle these "bootstrapping" problems will
be written in... shell.

Here are some places where shell scripts still exist, in quantity,
and are still being written:

- Installers (e.g. [rustup](https://github.com/rust-lang/rustup/blob/master/rustup-init.sh))
- System initialization (e.g. cloud instance user-data scripts, container entry points)
- CI/CD (e.g. CircleCI orbs)
- Configuration management

The reason these programs are so frequently written in some shell is
because it's the one thing you can "count on" to be installed on your
system already. Any other solution requires you to first deal with the
chicken-and-egg problem of installation. Yes, you can write your system
configuration in Chef, for example; but what installs Chef? You can
write your command-line tool in Python; but how do you make sure Python
is installed?

There are solutions to all these "bootstrapping" problems, and you can
imagine--with work, sometimes a lot of it, and sometimes on some other
party's part--how some of them are addressable using no shell at
all. But even image-based distribution still has to deal with these
bootstrapping concerns.[^3] You can push this problem around, but it's a
bit of a shell game--pun intended.

[^3]: It can get tricky, because the descent-based or layered way that
  container images get built--as a kind of whole system at once--is
  not that friendly to installing a tool here and a tool there. Multistage
  builds in Dockerfiles can get pretty complicated; and of course, are
  mostly written in--you guessed it--shell.

So, it's clear that (for many people, in many bootstrapping scenarios)
you want to _run_ a shell script, but you still don't want to _write_
it.  That's the problem Wrapsher is designed to solve. You write your
program in an attractive, safe language with the affordances you need
to write good code; but you run it using only a POSIX-complaint shell,
plus (optionally) safely-managed external dependencies.

## Inspiration: The very idea

_Or: What made you want to do such a thing?_

I took some initial inspiration from [Amber](https://amber-lang.com/),
which I read about on
[HN](https://news.ycombinator.com/item?id=40431835); and
[Ansible](https://www.ansible.com/), an agentless configuration
management system which I've loved to hate and hated to love. I wrote a
brief [comparison with Amber](./docs/amber-comparison.md).

I really liked the idea of allowing you to write programs in
a "good" programming language (with types, dependency management,
rich expressions) and execute it in a "ubiquitous" runtime. That has
potential to usefully solve the real problem described above.

## Getting Started: How do I run Wrapsher?

_Or: Hello, world?

For now, the Wrapsher compiler is implemented in Ruby and is installable
as a Ruby gem:

```shell
gem install wrapsher
```

Eventually, I would like to migrate further and further away from this
and implement more of wrapsher in itself. It's not _very_ important that
Wrapsher be self-hosted but it would be convenient, for all the reasons
described above that motivated its creation.

You can start by compiling the example "hello, world" program:

```shell
wrapsher compile examples/hello.wsh
./examples/hello
```

To hack on it, you can start by running the stdlib tests:

```shell
bundle install
bundle exec rake test
```

## Other Documents: How to read more?

_Or: How does it work?_

- [Wrapsher language](./wrapsher.md)
- [Internals](./internals.md)
- [Decisions](./decisions.md)
- [Roadmap](./roadmap.md)

---

> <sub>Copyright (c) 2025 Mermaidpurse
> [MPL-2.0](https://www.mozilla.org/MPL/2.0/) (code)
> [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) (docs)</sub>
