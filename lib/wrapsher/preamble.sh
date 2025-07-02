# wsh:preamble for scripts
_wshv_refid=1000

_wsh_typeof() {
  _wsh_type=''
  _wsh_type="${1%:*}"
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
    "${1%:*}") : ;;
    *)       _wsh_error="error:Expected type '${2}', got '${1%:*}': ${3} at $_wsh_line"
             return 1 ;;
  esac
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

# _wsh_dispatch function_name arg_type
_wsh_dispatch() {
  _wsh_typeof_underscore "${2}"
  _wsh_have_function_p "${1}" "${_wsh_type_underscore}"
  case "${_wsh_have_function}" in
    1) "_wshf_${1}_${_wsh_type_underscore}" || return 1 ;;
    *) _wsh_have_function_p "${1}" 'any'
       case "${_wsh_have_function}" in
         1) "_wshf_${1}_any" || return 1 ;;
         *) _wsh_error="error:No such n-ary function '${1}(${2}, ...)' at $_wsh_line"
            return 1 ;;
       esac ;;
  esac
}
