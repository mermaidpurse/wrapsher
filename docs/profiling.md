# Profiling

Wrapsher has very rudimentary profiling support that produces files suitable
for the Chrome Trace Viewer and other applications that support it--after a little
post-processing.

This takes advantage of a bash feature, so bash needs to be installed and support
the `EPOCHREALTIME` feature. NB: The bash `/bin/bash` on MacOS is actually zsh
and not suitable--install bash some other way (e.g. homebrew).

To enable profiling (compile with profiling enabled), run the compiler with
the `--profile` option pointing to a suitable `bash` executable. For example,
if you are using MacOS and have installed `bash` with homebrew:

```shell
bundle exec wrapsher --profile=/opt/homebrew/bin/bash wsh/core_test.wsh
```

The `wsh/core_test` executable has the profiler built-in, but it is dormant
unless activated by setting the `WSH_PROFILE` environment variable to a filename
which will collect tracing events. For example:

```shell
WSH_PROFILE=./trace.jsons wsh/core_test
```

The `./trace.jsons` file is a JSON stream file which requires slight post-processing:

```shell
bundle exec rake profile:trace[trace.jsons]
```

After that, you can load the resulting `/trace.json` file in
[Perfetto](https://ui.perfetto.dev),
[Speedscope](https://www.speedscope.app) or Chrome.
