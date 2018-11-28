#!/usr/bin/env bash
#
# DESCRIPTION
# Creates a blank TypeScript library project
#
# CREDITS
# Source  : https://github.com/adryo/scripts
# curl https://raw.githubusercontent.com/adryo/scripts/develop/create-ts-lib.sh | bash
###############################################################################


# Idenfity platform
PLATFORM=`uname`

echo "Hello $1, how are you?"

readonly NAME="$1"

if [[ "$NAME" != "" ]]; then
    if ! type jq >/dev/null 2>&1; then
        echo "'jq' not installed. Trying to install it automatically..."
        if [[ "$PLATFORM" == 'Linux' ]]; then
            sudo apt-get install jq
        else
            brew install jq
        if
    fi

    if ! type jq >/dev/null 2>&1; then
        echo "Unable to install 'jq'. Exiting..."
        exit 1
    fi

    echo "Cloning the repo..."
fi