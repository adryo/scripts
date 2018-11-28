#!/usr/bin/env bash
#
# DESCRIPTION
# Creates a blank TypeScript library project
#
# CREDITS
# Source  : https://github.com/adryo/scripts
# curl https://raw.githubusercontent.com/adryo/scripts/develop/create-ts-lib.sh | bash
###############################################################################

echo "Starting configuration..."
read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Idenfity platform
PLATFORM=`uname`

# Request name
read -p "Provide the lib name: " name

if [[ !  -z $name ]]; then
    if ! type jq >/dev/null 2>&1; then
        echo "'jq' not installed. Trying to install it automatically..."

        if [[ "$name" == 'Linux' ]]; then
            sudo apt-get install jq
        else
            brew install jq
        fi
    fi

    if ! type jq >/dev/null 2>&1; then
        echo "Unable to install 'jq'. Exiting..."
        exit 1
    fi

    git clone  "https://github.com/adryo/typescript-library.git" $name

    echo "Updating package.json info"
    content="$(jq ".name = \"$name\"" $name/package.json)"

    echo "$content" > "$name/package.json"

    cd $name && npm install && npm test
fi