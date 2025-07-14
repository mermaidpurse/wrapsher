# wsh:preamble for scripts
_wsh_stackp=0
_wsh_frame=0

_wsh_typeof() {
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

# or : ((_wsh_stack${_wsh_stackp}="${1}"))
# _wsh_stack_push arg
_wsh_stack_push() {
  _wsh_stackp=$((_wsh_stackp + 1))
  case "$((_wsh_stackp > 10000))" in 1)
    _wsh_error="error:Stack overflow at $_wsh_line"
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
  [[ -n ${WSH_DEBUG} ]] && _wsh_debug "  <= ${_wsh_result}"
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

# _wsh_scan_refs value => _wsh_outrefs
_wsh_scan_refs() {
  _wsh_scan_val="${1}"
  _wsh_outrefs=''
  _wsh_refs_to_scan=''
  _wsh_iter=0
  while : $((_wsh_iter++))
  do
    case "${_wsh_scan_val}" in type/*)
      # It's a type value, it can't contain refs
      _wsh_scan_val=''
      continue
    ;; ?*)
      # A value to scan for refs
      # strip it until it's down to a builtin type, then
      # see if it's a ref or reflist--the other builtins
      # can't contain refs
      _wsh_inner=0
      while : $((_wsh_inner++))
      do
        _wsh_scan_bare="${_wsh_scan_val%%:*}"
        _wsh_get_global "${_wsh_scan_bare}" _wsh_scan_type
        case "${_wsh_scan_type#type/${_wsh_scan_bare}:}" in builtin)
          case "${_wsh_scan_bare}" in reflist)
            for _wshi in ${_wsh_scan_val#reflist:}
            do
              _wsh_outrefs="${_wsh_outrefs} ${_wshi}"
              _wsh_refs_to_scan="${_wsh_refs_to_scan}${_wsh_refs_to_scan:+ }${_wshi}"
            done
          ;; ref)
            _wsh_outrefs="${_wsh_outrefs} ${_wsh_scan_val}"
            _wsh_refs_to_scan="${_wsh_refs_to_scan}${_wsh_refs_to_scan:+ }${_wsh_scan_val}"
          esac
          _wsh_scan_val=''
          break
        ;; *)
          _wsh_scan_val="${_wsh_scan_val#${_wsh_scan_bare}:}"
        ;;
        esac
      done
    ;; *)
      # No value to scan, see if there are refs left to scan
      case "${_wsh_refs_to_scan}" in ?*)
        # unshift the next ref to scan, and make it the
        # next value to scan
        _wshi="${_wsh_refs_to_scan%% *}"
        _wsh_refs_to_scan="${_wsh_refs_to_scan#${_wshi}}"
        _wsh_refs_to_scan="${_wsh_refs_to_scan# }"
        _wsh_deref_into "${_wshi}" _wsh_scan_val
      ;; *)
        # No refs to scan, either--we're done
        break
      esac
    esac
  done
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
