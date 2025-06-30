# wsh:postamble for scripts
_wsh_arg0='type/array:builtin'
_wshf_new_type_array
_wsh_arg0="${_wsh_result}"
for _wshi in "$@"
do
  # lift shtring to string and push onto array
  _wsh_arg0="string:${_wshi}"
  _wshf_push_array
  _wsh_arg0="${_wsh_result}"
done
_wsh_dispatch main array
_wsh_exitcode="$?"
_wsh_check "${_wsh_result}" 'int' 'main()' || _wsh_exitcode=1
echo "_wsh_result:${_wsh_result}"

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
