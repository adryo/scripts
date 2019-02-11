#!/usr/bin/env bash

# Variable to store the credential to be used in expect.
CURRENT_LOGON_PASSWORD=""

# Globals
GLOBAL_PLATFORM=`uname`

run_expect() {
  expect -c "set timeout -1; spawn $1; expect \"Password*\" {send \"$2\n\"; exp_continue} \"RETURN\" {send \"\n\"; exp_continue} $3"
}

expectify(){
  if [ -z "$CURRENT_LOGON_PASSWORD" ]; then
    read -s -p "Password (for $USER): " CURRENT_LOGON_PASSWORD
    echo ""
  fi

  run_expect "$1" "$CURRENT_LOGON_PASSWORD" "$2"
}
