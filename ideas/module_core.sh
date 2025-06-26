#!/bin/sh

# type/[/oftype[/precision]]
# int:8

# TYPE ITEM
__check() {
  __want_type="${2%%/*}" # remove collection type qualifier, if any
  __got_type="${3%%:*}"
  __got_type="${__got_type%%/*}"  # remove collection type qualifier, if any
  case "${__got_type}" in
    "${__want_type}") __error="" ;;
    *)     __error="${__loc:-(unk)}: ${1}: expected item of type ${__type}, got type ${3%%:*}"
           unset __want_type __got_type
           return 1 ;;
  esac
  unset __want_type __got_type
}

# useful? variables aren't nullable? maybe null is a return type indicating __result won't be set
__null_new() {
  __result='null:'
}

# FUN [ARGS ...]
__fun_apply() {
  __check fun_apply:self fun "${1}" || return 1
  __funname="${1#*:}"
  shift 1
  __result="$(__funname "$@")" || return 1
}

__bool_new() {
  __result='bool:false'
}

__bool_from_string() {
  __check from_string:0 string "${1}" || return 1
  case "${1#string:}" in
    true)  __result="bool:true" ;;
    false) __result="bool:false" ;;
    *)     __error="${__loc:-(unk)}: from_string:0: can't convert ${1#string:} to bool type"
           return 1 ;;
  esac
}

__bool_to_string() {
  __check to_string:self bool "${1}" || return 1
  __result="string:#{1#bool:}"
}

# Could this even work?
__panic() {
  __error="${__loc:-(unk)}: ${1}"
  exit 99
}

# internal function
__bool__to_arithmetic_int() {
  case "${2#bool:}" in
    true)  eval "$1=1" ;;
    false) eval "$1=0" ;;
  esac
}

__bool__from_arithmetic_int() {
  case "${2}" in
    0) eval "${1}=bool:false" ;;
    1) eval "${1}=bool:true" ;;
  esac
}

__bool_not() {
  __check not:self bool "${1}" || return 1
  case "${1#bool:}" in
    true)  __result='bool:false' ;;
    false) __result='bool:true' ;;
  esac
}

__bool_and() {
  __check and:self bool "${1}" || return 1
  __check and:0 bool "${2}" || return 1
  __bool__to_arithmetic_int __arg0 "${1}"
  __bool__to_arithmetic_int __arg1 "${2}"
  __res0=$((${__arg0} & ${__arg1}))
  unset __arg0 __arg1
  __bool__from_arithmetic_int __result "${__res0}"
  unset __res0
}

__bool_or() {
  __check and:self bool "${1}" || return 1
  __check and:0 bool "${2}" || return 1
  __bool_arithmetic_int __arg0 "${1}"
  __bool_arithmetic_int __arg1 "${2}"
  __res0=$((${__arg0} | ${__arg1}))
  unset __arg0 __arg1
  __bool__from_arithmetic_int __result "${__res0}"
  unset __res0
}

__bool_xor() {
  __check and:self bool "${1}" || return 1
  __check and:0 bool "${2}" || return 1
  __bool_arithmetic_int __arg0 "${1}"
  __bool_arithmetic_int __arg1 "${2}"
  __res0=$((${__arg0} ^ ${__arg1}))
  unset __arg0 __arg1
  __bool__from_arithmetic_int __result "${__res0}"
  unset __res0
}

# (int) new()
__int_new() {
  __result='int:0'
}

# (int) from_string(string s)
__int_from_string() {
  __check from_string:0 string "${1}" || return 1
  __result="int:${1#string:}"
}

__int_to_string() {
  __check to_string:self int "${1}" || return 1
  __result="string:${1#int:}"
}

__int_plus() {
  __check plus:self int "${1}" || return 1
  __check plus:0 int "${2}"    || return 1
  __result="int:$((${1#int:} + ${2#int:}))"
}

__int_minus() {
  __check minus:self int "${1}" || return 1
  __check minus:0 int "${1}"    || return 1
  __result="int:$((${1#int:} - ${2#int:}))"
}

__int_times() {
  __check times:self int "${1}" || return 1
  __check times:0 int "${1}"    || return 1
  __result="int:$((${1#int:} * ${2#int:}))"
}

__int_div() {
  __check div:self int "${1}" || return 1
  __check div:0 int "${1}"    || return 1
  __result="int:$((${1:int:} * ${2#int:}))"
}

# bool gt(int self, int operand) {
#   sh {
#     __bool_from_arithmetic_int __result $(("${1#int:}" > "${2#int:}"))
#   }
# }
__int_gt() {
  __check gt:self int "${1}" || return 1
  __check gt:0 int "${2}" || return 1
  __bool__from_arithmetic_int __result $((${1#int:} > ${2#int:}))
}

# bool ge(int self, int operand) {
#   sh {
#     __bool_from_arithmetic_int __result $((${1#int:} >= ${2#int:}))
#   }
# }
__int_ge() {
  __check ge:self int "${1}" || return 1
  __check ge:0 int "${2}" || return 1
  __bool__from_arithmetic_int __result $((${1#int:} >= ${2#int:}))
}

# bool lt(int self, int operand) {
#   sh {
#     __bool_from_arithmetic_int __result $(("${1#int:}" < "${2#int:}"))
#   }
# }
__int_lt() {
  __check lt:self int "${1}" || return 1
  __check lt:0 int "${2}" || return 1
  __bool__from_arithmetic_int __result $((${1#int:} < ${2#int:}))
}

# bool lt(int self, int operand) {
#   sh {
#     __bool_from_arithmetic_int __result $(("${1#int:}" <= "${2#int:}"))
#   }
# }
__int_lt() {
  __check lt:self int "${1}" || return 1
  __check lt:0 int "${2}" || return 1
  __bool__from_arithmetic_int __result $((${1#int:} <= ${2#int:}))
}

# type int
# int mod(int self, int a) {
#   self % a
# }
__int_mod() {
  __check div:self int "${1}" || return 1
  __check div:0 int "${1}"    || return 1
  __result="int:$((${1:int:} * ${2#int:}))"
}

__string_new() {
  __result="string:"
}

__string_len() {
  __check len:self string "${1}" || return 1
  __arg="${1#string:}"
  __result="${#__arg}"
  unset __arg
}

# TODO: need quoting of pattern metacharacters
# string trimprefix(string self, string prefix) {
#   sh {
#     __arg0="${1#string:}"
#     __arg1="${2#string:}"
#     __result="${__arg0#${__arg1}}"
#   }
# }
__string_trimprefix() {
  __check trimprefix:self string "${1}" || return 1
  __check trimprefix:0 string "${2}" || return 1
  __arg0="${1#string:}"
  __arg1="${2#string:}"
  __result="${__arg0#${__arg1}}"
}

__string_trimsuffix() {
  __check trimsuffix:self string "${1}" || return 1
  __check trimprefix:0 string "${2}" || return 1
  __arg0="${1#string:}"
  __arg1="${2#string:}"
  __result="${__arg0%${__arg1}}"
}

# References for compound types--these references
# are always internal so we shouldn't have to worry
# about leaking--they are destroyed when removed
# from the collection
__wsh_id_sequence=1000

__wsh_next_id() {
  eval "${1}=$__wsh_id_sequence"
  __wsh_id_sequence=$(($__wsh_id_sequence + 1))
}

__wsh_create_ref() {
  __wsh_next_id __wsh_myid
  eval "${1}=__wsh_ref_${__wsh_myid}"
  eval "__wsh_ref_${__wsh_myid}=\"${2}\"" # TODO: this is very unsafe with regard to quoting
  unset __wsh_myid
}

__wsh_destroy_ref() {
  eval "unset ${1}"
}

__wsh_deref() {
  eval "${1}"
}

__collection_type() {
  __wsh_header="${2%%:*}"
  eval "${1}=\"${__header#*/}\""
  unset __wsh_header
}

# array/type:ref[,ref[,...]]
# maybe * works? and should work?

__array_new() {
  __check new:0 type "${1}" || return 1
  __result="array/${1#type:}:"
}

# int len(array a) {
#   sh {
#     set -- ${1#array/*:}
#     __result=$#
#   }
# }
__array_len() {
  __check len:self array/* "${1}" || return 1
  set -- ${1#array/*:}
  __result=$#
}

# any at(array self, int i) {
__array_at() {
  __check at:self array/* "${1}" || return 1
  __check at:0 int "${2}" || return 1
  __array_len "${1}"
  __len="${__result}"
  # Could be done with int and bool methods, but wordy
  case $((${2#int:} >= 0 && ${2#int:} < ${__len#int:})) in
    0) __error="${__loc:-(unk)}: at:0 array subscript out of bounds [0..${__len#int:})"
       return 1 ;;
  esac
  __i="${2#int:}"
  __iter=0
  set -- ${1#array/*:}
  for __item in "$@"
  do
    case ${__iter} in
      ${__i}) eval "__result=\$${__item}"
              break ;;
    esac
    __iter=$(($__iter + 1))
  done
  unset __i __iter
}

# array insert(array self, int i, any value) {
__array_insert() {
  __check at:self array/* "${1}" || return 1
  __check at:0 int "${2}" || return 1
  __array_len "${1}"
  __len="${__result}"
  unset __result
  case $((${2#int:} >= 0 && ${2#int:} <= ${__len#int:})) in
    0) __error="${__loc:-(unk)}: insert:0 array subscript out of bounds [0..${__len#int:}]"
       return 1 ;;
  esac
  __wsh_create_ref __ref "${3}"
  # special case--insert at end of empty array
  case ${__len#int:} in
    0) __result="${1}${__ref}"
       unset __len __ref
       return 0 ;;
  esac
  __self="${1}"
  __new_list=
  __i="${2#int:}"
  __iter=0
  set -- ${__self#array/*:}
  for __item in "$@"
  do
    case ${__iter} in
      ${__i}) case "${__new_list}" in
                '') __new_list="${__ref}" ;;
                *)  __new_list="${__new_list} ${__ref}" ;;
              esac ;;
    esac
    __iter=$(($__iter + 1))
    case "${__new_list}" in
      '') __new_list="${__item}" ;;
      *)  __new_list="${__new_list} ${__item}" ;;
    esac
  done
  __result="${__self%%:*}:${__new_list}"
  unset __self __ref __new_list __i __iter __item
}

# array delete_at(array self, int i) {
__array_delete_at() {
  __check delete_at:self array/* "${1}" || return 1
  __check delete_at:0 int "${2}" || return 1
  __array_len "${1}"

  # len = self.len
  __len="${__result}"
  unset "${__result}"

  # if i <= 0 or i >= len {
  #   throw "array subscript out of bounds [0..$len)"
  # }
  case $((${2#int:} >= 0 && ${2#int:} < ${__len#int:})) in
    0) __error="${__loc:-(unk)}: delete_at:0 array subscript out of bounds [0..${__len#int:})"
       return 1 ;;
  esac

  __self="${1}"
  __new_list=
  __i="${2#int:}"
  __iter=0
  set -- ${__self#array/*:}
  for __item in "$@"
  do
    case ${__iter} in
      ${__i}) __wsh_destroy_ref "${__item}" ;;
      *) case "${__new_list}" in
           '') __new_list="${__item}" ;;
           *)  __new_list="${__new_list} ${__item}" ;;
         esac ;;
    esac
    __iter=$(($__iter + 1))
  done
  __result="${__self%%:*}:${__new_list}"
  unset __self __new_list __i __iter __item
}

# array push(array self, any value) {
__array_push() {
  __check push:self array/* "${1}" || return 1
  __collection_type __type "${1}"
  __check push:0 "${__type}" "${2}" || return 2
  unset __type

  # len = self.len
  __array_len "${1}"
  __len="${__result}"
  unset __result

  # self.insert len value
  __array_insert "${1}" "${__len}" "${2}"
}

# array slice(array self, array/int is) {

# array select(array self, fun) {

# array map(array self, fun) {
