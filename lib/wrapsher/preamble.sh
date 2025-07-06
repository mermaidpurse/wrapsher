# wsh:preamble for scripts
_wsh_stackp=0
_wsh_frame=0

_wsh_typeof() {
  _wsh_type=''
  _wsh_type="${1%%:*}"
}

_wsh_typeof_underscore() {
  _wsh_typeof "${1}"
  _wsh_type_underscore=''
  while true
  do
    case "${_wsh_type}" in
      */*) case "${_wsh_type_underscore}" in
             '') _wsh_type_underscore="${_wsh_type%%/*}" ;;
             *)  _wsh_type_underscore="${_wsh_type_underscore}_${_wsh_type%%*}" ;;
           esac
           _wsh_type="${_wsh_type#*/}" ;;
      *)   case "${_wsh_type_underscore}" in
             '') _wsh_type_underscore="${_wsh_type}" ;;
             *)  _wsh_type_underscore="${_wsh_type_underscore}_${_wsh_type}" ;;
           esac
           _wsh_type='' ;;
    esac
    case "${_wsh_type}" in
      '') break ;;
    esac
  done
}

_wsh_assert() {
  case "${2}" in
    any)       : ;;
    "${1%%:*}") : ;;
    *)       _wsh_error="error:Expected type '${2}', got '${1%%:*}': ${3} at $_wsh_line"
             return 1 ;;
  esac
}

# Should these evals be reads?
# or : ((_wsh_stack${_wsh_stackp}="${1}"))
# _wsh_stack_push arg
_wsh_stack_push() {
  _wsh_stackp=$((_wsh_stackp + 1))
  eval "_wsh_stack${_wsh_stackp}=\"\${1}\""
}

# _wsh_stack_peek_into var_name
_wsh_stack_peek_into() {
  eval "${1}=\"\${_wsh_stack${_wsh_stackp}}\""
}

# _wsh_stack_pop_into var_name
_wsh_stack_pop_into() {
  eval "${1}=\"\${_wsh_stack${_wsh_stackp}}\""
  _wsh_stackp=$((_wsh_stackp - 1))
}

# _wsh_set wrapsher_var_name value
_wsh_set_local() {
  _wsh_cleanup="${_wsh_cleanup} _wshv_${_wsh_frame}_${1}"
  eval "_wshv_${_wsh_frame}_${1}=\"\${2}\""
}

# _wsh_set_global wrapsher_var_name value
_wsh_set_global() {
  eval "_wshg_${1}=\"\${2}\""
}

# _wsh_get_local wrashper_var_name var_name
_wsh_get_local() {
  eval "${2}=\"\${_wshv_${_wsh_frame}_${1}}\""
}

# _wsh_get_global wrapsher_var_name var_name
_wsh_get_global() {
  eval "${2}=\"\${_wshg_${1}}\""
}

# _wsh_deref_into ref_value var_name
_wsh_deref_into() {
  eval "${2}=\"\${_wshr_${1#ref:}}\""
}

# Should the function presence predicate be a function which sets
# the signal variable, and eliminate this eval?
# _wsh_have_function function_name [arg_type_qualifier]
_wsh_have_function_p() {
  eval "_wsh_have_function=\"\${_wshp_${1}${2:+_}${2}}\""
}

# _wsh_dipatch_null pred function_name
_wsh_dispatch_nullary() {
  _wsh_have_function_p "${1}"
  case "${_wsh_have_function}" in
    1) _wsh_run "_wshf_${1}" || return 1 ;;
    *) _wsh_error="error:No such nullary function '${1}' at $_wsh_line"
       return 1 ;;
  esac
}

# _wsh_run resolved_function_name
_wsh_run() {
  _wsh_cleanup=''
  : $((_wsh_frame++))
  _wsh_set_local _reflist 'reflist:'
  "${1}" || return 1
  # clean up frame-local variables
  unset ${_wsh_cleanup}
  _wsh_cleanup=''
  # find refs to be protected
  _wsh_outrefs=''
  _wsh_scan_refs "${_wsh_result}"
  _wsh_get_local _reflist _wshi
  # clean up refs that we aren't passing out
  _wsh_cleanup_refs "${_wshi}" "${_wsh_outrefs}"
  : $((_wsh_frame--))
  # import protected outrefs into parent scope's
  # reflist
  _wsh_get_local _reflist _wshi
  case "${_wshi}" in reflist:)
    _wsh_set_local _reflist "reflist:${_wsh_outrefs# }"
  ;; *)
    _wsh_set_local _reflist "reflist:${_wshi#reflist:} ${_wsh_outrefs# }"
  ;;
  esac
}

# _wsh_scan_refs value
_wsh_scan_refs() {
  _wsh_typeof "${1}"
  _wsh_get_global "${_wsh_type}" _wsh_typeof_type
  case "${_wsh_typeof_type#type/${_wsh_type}:}" in builtin)
    case "${_wsh_type}" in ref)
      _wsh_outrefs="${_wsh_outrefs} ${1}"
      _wsh_deref_into "${1}" _wshi
      _wsh_scan_refs "${_wshi}"
    ;; reflist)
      for _wshi in ${1#reflist:}
      do
        _wsh_outrefs="${_wsh_outrefs} ${_wshi}"
      done
    ;;
    esac
  ;; '')
    _wsh_error="error:Unknown type '${_wsh_type}' at $_wsh_line"
    return 1
  ;; *)
    # scan wrapped value
    _wsh_scan_refs "${1#${_wsh_type}:}"
  ;;
  esac
}

# _wsh_cleanup_refs _reflist raw_outrefs
_wsh_cleanup_refs() {
  for _wshi in ${1#reflist:}
  do
    case "${_raw_outrefs}" in *${_wshi}\ *)
      :
    ;; *${_wshi})
      :
    ;; *)
      unset "$_wshr_${_wshi#ref:}"
    ;;
    esac
  done
}

_wsh_debug() {
  echo "Debug: ${1}" >&2
  _wsh_debug_stack >&2
}

_wsh_debug_stack() {
  echo "Stack: "
  for ((i=_wsh_stackp; i > 0; i--))
  do
    eval "echo \"  _wsh_stack${i}='\${_wsh_stack${i}}'\" >&2"
  done
}

# _wsh_dispatch function_name
_wsh_dispatch() {
  [[ -n ${WSH_DEBUG} ]] && _wsh_debug "Dispatching function '${1}'"
  _wsh_stack_peek_into _wsh_arg0
  _wsh_typeof_underscore "${_wsh_arg0}"
  _wsh_have_function_p "${1}" "${_wsh_type_underscore}"
  case "${_wsh_have_function}" in
    1) _wsh_run "_wshf_${1}_${_wsh_type_underscore}" || return 1 ;;
    *) _wsh_have_function_p "${1}" 'any'
       case "${_wsh_have_function}" in
         1) _wsh_run "_wshf_${1}_any" || return 1 ;;
         *) _wsh_error="error:No such n-ary function '${1}(${_wsh_arg0%%:*}, ...)' at $_wsh_line"
            return 1 ;;
       esac ;;
  esac
}

_wsh_panic() {
  _wsh_exitcode="${1}"
  if [[ "${_wsh_error#error:}" ]]
  then
    # the one place we unconditionally use I/O
    # and the echo command. Even though it's external,
    # this is basically a panic, so we have to
    # bootstrap it. Maybe someday we can be smarter
    # about this.
    echo "${_wsh_error#error:}" >&2
  else
    echo "error:Unspecified, ${2} exited"
  fi
  exit "${_wsh_exitcode}"
}
