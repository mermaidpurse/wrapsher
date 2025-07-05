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

# _wsh_get_global wrashper_var_name var_name
_wsh_get_global() {
  eval "${2}=\"\${_wshg_${_wsh_frame}_${1}}\""
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
    1) "_wshf_${1}" || return 1 ;;
    *) _wsh_error="error:No such nullary function '${1}' at $_wsh_line"
       return 1 ;;
  esac
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
    1) "_wshf_${1}_${_wsh_type_underscore}" || return 1 ;;
    *) _wsh_have_function_p "${1}" 'any'
       case "${_wsh_have_function}" in
         1) "_wshf_${1}_any" || return 1 ;;
         *) _wsh_error="error:No such n-ary function '${1}(${_wsh_arg0%%:*}, ...)' at $_wsh_line"
            return 1 ;;
       esac ;;
  esac
}
