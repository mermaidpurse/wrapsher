# wsh:postamble for scripts
_wsh_dispatch_nullary _init || _wsh_panic $? "init()"

_wsh_get_global list _wshi
_wsh_stack_push "${_wshi}"
_wsh_line="postamble.sh:5"
_wsh_dispatch new || _wsh_panic $? "list.new()"
_wshv_argv="${_wsh_result}"
for _wshi in "$@"
do
  # lift raw string to wrapsher string and push onto list argv
  _wsh_stack_push "string:${_wshi}"
  _wsh_stack_push "${_wshv_argv}"
  _wsh_line="postamble.sh:13"
  _wsh_dispatch push || _wsh_panic "argv.push(${_wshi})"
  _wshv_argv="${_wsh_result}"
done

_wsh_stack_push "${_wshv_argv}"
_wsh_line="postamble.sh:19"
_wsh_dispatch main || _wsh_panic $? "main(${_wshv_argv})"
exit "${_wsh_result#int:}"
