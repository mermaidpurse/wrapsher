# wsh:preamble for scripts
_wsh_result='null:'
_wsh_refid=999
_wsh_error='error:'

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

_wsh_check() {
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

# We have to implement the language primitives here. Eventually I think
# we can move this to use a lot of wsh code, but not until we have
# at least the sh block/here-doc working.

# any has to be special in function dispatch. Hm.
# garbage collection for refs is not implemented.
# if refs are only an internal mechanism for arrays and maps,
# then since we are always returning values, we can destroy
# them when removed from the collection.

# ref new(any v) {
#   sh <<EOF
#     _wsh_refid=$((${_wsh_refid} + 1))
#     read ...
#     _wsh_result="ref:${_wsh_refid}"
#   EOF
# }
_wshp_new_ref_any=1
_wshf_new_ref_any() {
  _wsh_result='null:'
  _wsh_error='error:'
  _wsh_refid=$((${_wsh_refid} + 1))
  read "_wshr_${_wsh_refid}" <<EOF || return 1
"${_wsh_arg0}"
EOF
  _wsh_result="ref:${_wsh_refid}"
}

# any deref(ref r) {
_wshp_deref_ref=1
_wshf_deref_ref() {
  _wsh_result='null:'
  _wsh_error='error:'
  _wshv_r="${_wsh_arg0}"
  unset _wsh_arg0
  eval "_wsh_result=\"\${_wshr_${_wshv_r#ref:}}\""
  unset _wshv_r
}

# void destroy
_wshp_destry_ref=1
_wshf_destroy_ref() {
  _wsh_result='null:'
  _wsh_error='error:'
  _wshv_r="${_wsh_arg0}"
  unset _wsh_arg0
  unset "_wshr_${_wshv_r#ref:}"
  unset _wshv_r
}

# array new(type/array t) {
#   sh <<EOF
#     _wsh_result='array:'
#   EOF
# }
_wshp_new_type_array=1
_wshf_new_type_array() {
  _wsh_result='null:'
  _wsh_error='error:'
  _wshv_t="${_wsh_arg0}"
  unset _wsh_arg0
  _wsh_check "${_wshv_t}" 'type/array' 't' || return 1
  _wsh_result='array:'
  _wsh_check "${_wsh_result}" 'array' 'new()' || return 1
}

# array push(array a, any v) {
_wshp_push_array=1
_wshf_push_array() {
  _wsh_result='null:'
  _wsh_error='error:'
  _wshv_a="${_wsh_arg0}"
  unset _wsh_arg0
  _wsh_check "${_wshv_a}" 'array' 'a' || return 1
  _wshv_v="${_wsh_arg1}"
  unset _wsh_arg1
  _wsh_check "${_wshv_v}" 'any' 'v' || return 1

  _wsh_arg0="${_wshv_v}"
  _wsh_dispatch new_ref "${_wsh_arg0}" || return 1

  case "${_wshv_}" in
    array:) _wsh_result="${_wshv_a}${_wsh_result}" ;;
    *) _wsh_result="${_wshv_a}${_wsh_result}" ;;
  esac
  _wsh_check "${_wsh_result}" 'array' 'push()' || return 1
}
