#!/bin/sh

# module io
# load core?
# Get fancy with fds
use external printf

# void printf(string fmt, arg any...)
# variadic is actually pretty hard
__io_printf() {
  __check io.printf:0 string "${1}" || return 1
  __fmt="${1#string:}"
  shift 1
  __i=0
  for __arg in "$@"
  do
    eval 

