# wsh:preamble for scripts
# Clear environment variables to prevent injection of bad initial values in `_wsh_ variables
_wsh_clearenv() {
  _wsh_clearenv_env="$(export -p)"
  _wsh_iter=0
  while
    : $((_wsh_iter++))
  do
    _wsh_clearenv_var="${_wsh_clearenv_env%%$'\n'*}"
    _wsh_clearenv_env="${_wsh_clearenv_env#*$'\n'}"
    case "${_wsh_clearenv_var}" in 'export _wsh'*)
      _wsh_clearenv_toclear="${_wsh_clearenv_var#export }"
      _wsh_clearenv_toclear="${_wsh_clearenv_toclear%%=*}"
      unset "${_wsh_clearenv_toclear}"
    ;;
    esac
    case "${_wsh_clearenv_var}" in "${_wsh_clearenv_env}")
      break
    ;;
    esac
  done
}
_wsh_clearenv

_wsh_stackp=0
_wsh_frame=0
_wsh_refid=1000

# _wsh_typeof value => _wsh_type
_wsh_typeof() {
  _wsh_type=''
  _wsh_type="${1%%:*}"
  _wsh_type="${_wsh_type%%+*}"
}

# _wsh_fundamental_typeof value => _wsh_fundamental_type
_wsh_fundamental_typeof() {
  _wsh_fundamental_type=''
  _wsh_fundamental_type="${1%%:*}"
  _wsh_fundamental_type="${_wsh_fundamental_type##*+}"
}

# _wsh_typeof_underscore type_name => _wsh_type_underscore
_wsh_typeof_underscore() {
  _wsh_local_type=''
  _wsh_typeof "${1}"
  _wsh_type_underscore=''
  _wsh_local_type="${_wsh_type}"
  while
    :
  do
    case "${_wsh_local_type}" in */*)
      case "${_wsh_type_underscore}" in '')
        _wsh_type_underscore="${_wsh_local_type%%/*}"
      ;; *)
        _wsh_type_underscore="${_wsh_type_underscore}__${_wsh_local_type%%*}"
      ;;
      esac
      _wsh_local_type="${_wsh_local_type#*/}"
    ;; *)
      case "${_wsh_type_underscore}" in '')
        _wsh_type_underscore="${_wsh_local_type}"
      ;; *)
        _wsh_type_underscore="${_wsh_type_underscore}__${_wsh_local_type}"
      ;;
      esac
      _wsh_local_type=''
    ;;
    esac
    case "${_wsh_local_type}" in '')
      break
    ;;
    esac
  done
}

# _wsh_assert value expected_type context/location
_wsh_assert() {
  _wsh_typeof "${1}"
  case "${2}" in any)
    :
  ;; "${_wsh_type}")
    :
  ;; *)
    _wsh_error="error:Expected type '${2}', got '${_wsh_type}': ${3}"
    return 1
  ;;
  esac
}

# or : ((_wsh_stack${_wsh_stackp}="${1}"))
# _wsh_stack_push arg
_wsh_stack_push() {
  _wsh_stackp=$((_wsh_stackp + 1))
  case "$((_wsh_stackp > 10000))" in 1)
    _wsh_error="error:Stack overflow pushing '${1}'
at ${_wsh_line}"
    _wsh_panic 1 "_wsh_stack_push"
  ;;
  esac
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

# _wsh_makeref_into() value var_name
_wsh_makeref_into() {
  : $((_wsh_refid++))
  _wsh_value="${1}"
  _wsh_fundamental_typeof "${_wsh_value}"
  eval "_wshr_${_wsh_refid}=\"\${_wsh_value}\""
  _wsh_ref="ref:${_wsh_refid}"
  case "${_wsh_fundamental_type}" in ref)
    _wsh_ref="${_wsh_ref}:${_wsh_value#ref:}"
  ;; reflist)
    for _wsh_makeref_subref in ${_wsh_value#*:}
    do
      _wsh_ref="${_wsh_ref}:${_wsh_makeref_subref#ref:}"
    done
  ;;
  esac
  eval "${2}=\"\${_wsh_ref}\""
  _wsh_get_local _reflist _wsh_makeref_reflist
  case "${_wsh_makeref_reflist}" in reflist:)
    _wsh_set_local _reflist "${_wsh_makeref_reflist}${_wsh_ref}"
  ;; *)
    _wsh_set_local _reflist "${_wsh_makeref_reflist} ${_wsh_ref}"
  ;;
  esac
}

# _wsh_deref_into ref_value var_name
_wsh_deref_into() {
  _wsh_deref_refid="${1#ref:}"
  _wsh_deref_refid="${_wsh_deref_refid%%:*}"
  eval "${2}=\"\${_wshr_${_wsh_deref_refid}}\""
}

# Should the function presence predicate be a function which sets
# the signal variable, and eliminate this eval?
# _wsh_have_function function_name [arg_type_qualifier]
_wsh_have_function_p() {
  eval "_wsh_have_function=\"\${_wshp_${1}${2:+_}${2}}\""
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
  [[ -n ${WSH_DEBUG} ]] && _wsh_debug "  <= ${_wsh_result}"
  _wsh_scan_refs "${_wsh_result}"
  _wsh_get_local _reflist _wshi
  # clean up refs that we aren't passing out
  _wsh_cleanup_refs "${_wshi}" "${_wsh_outrefs}"
  # Close frame
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

# _wsh_scan_refs value => _wsh_outrefs
# _wsh_outrefs is a raw "reflist" (space-separated list of refs without a reflist: tag)
_wsh_scan_refs() {
  _wsh_outrefs=''
  _wsh_fundamental_typeof "${1}"
  case "${_wsh_fundamental_type}" in ref)
    _wsh_outrefs="${1}"
  ;; reflist)
    _wsh_outrefs="${1#*:}"
  esac
}

# _wsh_cleanup_refs _reflist raw_outrefs
# clean up garbage for unreferenced refs
_wsh_cleanup_refs() {
  for _wsh_cleanup_ids in ${1#reflist:}
  do
    _wsh_cleanup_ids="${_wsh_cleanup_id#ref:}"
    _wsh_iter=0
    while
      : $((_wsh_iter++))
    do
      case "${2}" in *:${_wsh_cleanup_id%%:*}\ *)
        :
      ;; *:${_wsh_cleanup_id%%:*}:)
        :
      ;; *:${_wsh_cleanup_id%%:*})
        :
      ;; *)
        unset "$_wshr_${_wsh_cleanup_id}"
      ;;
      esac
      case "${_wsh_cleanup_id}" in *:*)
        _wsh_cleanup_id="${_wsh_cleanup_id#*:}"
      ;; *)
        break
      ;;
      esac
    done
  done
}

_wsh_debug() {
  echo "${_wsh_line} Debug: ${1}" >&2
  _wsh_debug_stack >&2
}

_wsh_debug_stack() {
  echo "                    Stack: " >&2
  for ((i=_wsh_stackp; i > 0; i--))
  do
    eval "echo \"                      _wsh_stack${i}='\${_wsh_stack${i}}'\" >&2"
  done
}

# _wsh_dispatch function_name arity
_wsh_dispatch() {
  [[ -n ${WSH_DEBUG} ]] && _wsh_debug "Dispatching ${2}-ary function '${1}'"
  case "${2}" in 0)
    _wsh_have_function=
    eval "_wsh_have_function=\"\${_wshp_${1}_0}\""
    case "${_wsh_have_function}" in 1)
      _wsh_run "_wshf_${1}_0" || return 1
    ;; *)
      _wsh_error="error:No such 0-ary function '${1}'"
      return 1
    ;;
    esac
  ;; *)
    _wsh_stack_peek_into _wsh_arg0
    _wsh_typeof_underscore "${_wsh_arg0}"
    _wsh_have_function=
    eval "_wsh_have_function=\"\${_wshp_${1}_${2}_${_wsh_type_underscore}}\""
    case "${_wsh_have_function}" in 1)
      _wsh_run "_wshf_${1}_${2}_${_wsh_type_underscore}" || return 1
    ;; *)
      _wsh_have_function=
      eval "_wsh_have_function=\"\${_wshp_${1}_${2}_any}\""
      case "${_wsh_have_function}" in 1)
        _wsh_run "_wshf_${1}_${2}_any" || return 1
      ;; *)
        _wsh_error="error:No such ${2}-ary function ${1}(${_wsh_type}[, ...])"
        return 1
      ;;
      esac
    esac
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
    # echo "${_wsh_error#error:}" >&2
    echo "${_wsh_error}" >&2
  else
    echo "error:Unspecified, ${2} exited"
  fi
  exit "${_wsh_exitcode}"
}

# _wsh_check_return addl_context
_wsh_check_return() {
  case "${_wsh_error}" in ?*)
    case "${1}" in ?*)
      _wsh_error="${_wsh_error}
  ^ ${1}"
    ;;
    esac
    return 1
  ;;
  esac
}
