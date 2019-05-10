# Overview

This scripts are built to be run in order to automatize some tasks and speed up the development.

## Create-ts-lib.sh

Creates a blank TypeScript setup project oriented to CI/CD.

## Setup-mac-azure-pipeline-agent
Setup a macos fresh installation with all the resources to develop iOS, Android, Scala, NodeJS applications.

### Usage
Open a command line application (terminal), cd to the desired directory and execute the following:

#### Unix based (Linux/MacOS)

bash <(curl https://raw.githubusercontent.com/adryo/scripts/master/create-ts-lib.sh)

bash <(curl https://raw.githubusercontent.com/adryo/scripts/master/setup/ubuntu-server-18.04.1.sh)

bash <(curl https://raw.githubusercontent.com/adryo/scripts/master/setup/mac-azure-pipeline-agent.sh) --logon-password $LogonPassword --apple-account $AppleUser --apple-password $ApplePassword
