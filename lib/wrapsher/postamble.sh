# wsh:postamble for scripts
_wsh_stack_push 'type/list:builtin'
_wsh_line="postamble.sh:4"
_wsh_dispatch new
_wsh_exitcode="$?"
_wshv_argv="${_wsh_result}"
# TODO: fix
for _wshi in "$@"
do
  # lift shtring to string and push onto list argv
  _wsh_arg0="${_wshv_argv}"
  _wsh_arg1="string:${_wshi}"
  _wsh_line="postamble.sh:13"
  _wsh_dispatch push "${_wsh_arg0}"|| return 1
  _wshv_argv="${_wsh_result}"
done

_wsh_stack_push "${_wshv_argv}"
_wsh_line="postamble.sh:19"
_wsh_dispatch main
_wsh_exitcode="$?"

# Handle uncaught exceptions
if [[ "${_wsh_exitcode}" -ne 0 ]]
then
  if [[ "${_wsh_error#error:}" ]]
  then
    # the one place we unconditionally use I/O
    # and the echo command. Even though it's external,
    # this is basically a panic, so we have to
    # bootstrap it. Maybe someday we can be smarter
    # about this.
    echo "${_wsh_error#error:}" >&2
    exit 1
  fi
fi
exit "${_wsh_result#int:}"
