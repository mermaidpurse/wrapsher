# wsh:postamble for scripts
_wsh_dispatch _init 0 || _wsh_panic $? "init()"

_wsh_get_global list _wshi
_wsh_stack_push "${_wshi}"
_wsh_line="postamble.sh:7"
_wsh_dispatch new 1 || _wsh_panic $? "list.new()"
_wshv_argv="${_wsh_result}"
for _wshi in "$@"
do
  # lift raw string to wrapsher string and push onto list argv
  _wsh_stack_push "string:${_wshi}"
  _wsh_stack_push "${_wshv_argv}"
  _wsh_line="postamble.sh:15"
  _wsh_dispatch push 2 || _wsh_panic "argv.push(${_wshi})"
  _wshv_argv="${_wsh_result}"
done

_wsh_stack_push "${_wshv_argv}"
_wsh_line="postamble.sh:21"
_wsh_dispatch main 1 || _wsh_panic $? "main(${_wshv_argv})"
exit "${_wsh_result#int:}"
