#!/usr/bin/env bash

# Import globals
source /dev/stdin <<< "$(curl --insecure -sS https://raw.githubusercontent.com/adryo/scripts/master/setup/globals.sh)" || exit 1

# Global Variables
APPLE_USER=""
APPLE_PASSWORD=""

# TFS Variables
# VSTS Agent Variables
readonly AZURE_AGENT_VERSION="2.150.3"
AGENT_NAME="VM-$GLOBAL_PLATFORM_OS-$(uuidgen)"
CONFIGURE_AZURE_PIPELINE_AGENT=1
SERVER_URL=""
TOKEN=""
POOL=""
TIMEZONE=""
INSTALL_XCODE=1
XCODE_VERSIONS=(10.2)
INSTALL_ANDROID=0

# This function is used to initialize the variables according to the supplied values through the scripts arguments
while [ "$#" -ne 0 ]; do
  ARG="$1"
  shift # get rid of $1, we saved in ARG already
  case "$ARG" in
  --install-script)
    echo "Requested to install local script..."
    readonly scriptFile="$HOME/macos-agent.sh"
    if [ -f "$scriptFile" ]; then
        rm "$scriptFile"
    fi

    echo "Installing script..."
    echo "#!/usr/bin/env bash" >> $scriptFile
    echo "#" >> $scriptFile
    echo "# Importing online file" >> $scriptFile
    echo 'bash <(curl -sS https://raw.githubusercontent.com/adryo/scripts/master/setup/mac-azure-pipeline-agent.sh) "$@" || exit 1' >> $scriptFile
    chmod +x "$scriptFile"
    echo "Script installed"
    exit 0
    ;;
  --apple-account)
    APPLE_USER=$1
    shift
    ;;
  --apple-password)
    APPLE_PASSWORD=$1
    shift
    ;;
  --skip-agent-config)
    CONFIGURE_AZURE_PIPELINE_AGENT=0
    ;;
  --install-android)
    INSTALL_ANDROID=1
    ;;
  --agent-name)
    AGENT_NAME=$1
    shift
    ;;
  --server-url)
    SERVER_URL=$1
    shift
    ;;
  --token)
    TOKEN=$1
    shift
    ;;
  --pool-name)
    POOL=$1
    shift
    ;;
  --timezone)
    TIMEZONE=$1
    shift
    ;;
  --skip-xcode-install)
    INSTALL_XCODE=0
  ;;
  --install-xcode)
    IN="$(echo -e "$1" | tr -d '[:space:]')"
    IFS=',' read -ra VERS <<<"$IN"
    for v in "${VERS[@]}"; do
      # process "$v"
      XCODE_VERSIONS=("${XCODE_VERSIONS[@]}" "$v")
    done
    shift
    ;;
  --help)
    echo "Usage:"
    echo ""
    echo "./script.sh [--options]"
    echo ""
    echo "Available options:"
    echo "--help: Display the usage tips plus tasks and options descriptions."
    echo "--install-script: Installs a shortcut of the current script in the Home directory, making you able to use the script like: ~/script.sh [tasks] [options]."
    echo "--logon-password: Sets the server credential for the script to act as sudo user while needed."
    echo "--apple-account: A valid developer account email to download and install Xcode."
    echo "--apple-password: The matching password to handle authentication through apple services."
    echo "--skip-agent-config: Runs the installation of the development tools but don't install any azure agent."
    echo "--agent-name: Sets the name of the agent in the azure platform's pool. Default is 'VM-Darwin-Mojave01'."
    echo "--server-url: The tfs or azure server's url."
    echo "--token: A valid PAT to use during agent configuration."
    echo "--pool-name: The pool where this agent will belong. Default is 'default'."
    echo "--timezone: The timezone to configure the agent with. Default is 'Europe/Paris'."
    echo "--install-android: If specified, installs the android sdk, ndk, tools and configures the env to use them."
    echo "--skip-xcode-install: Avoids the xcode installation."
    echo "--install-xcode: By default this script will install always Xcode 10.1, but other versions can be set to be automatically installed too. Set the version number separated by comma, ex: '--install-xcode 9.4,10.0'."
    exit 0
    ;;
  *)
    echo "Invalid command or option '$ARG'. Execute --help to see valid arguments."
    exit 1
    ;;
  esac
done

##VSTS Agent##
#https://github.com/Microsoft/azure-pipelines-agent/blob/master/README.md
#https://github.com/Microsoft/azure-pipelines-agent/blob/master/docs/start/envosx.md
installAzureAgent(){
  if [ -z "$SERVER_URL" ]; then
    read -p "TFS server's url: " SERVER_URL
  fi

  if [ -z "$TOKEN" ]; then
    read -s -p "Insert PAT: " TOKEN
    echo ""
  fi

  if [ -z "$POOL" ]; then
    POOL="default"
  fi

  if [ -z "$TIMEZONE" ]; then
    TIMEZONE="Europe/Paris"
  fi

  local readonly AZURE_AGENT_HOME="AzureAgents"
  local readonly AGENT_INSTANCE="$AZURE_AGENT_HOME/agent01"
  
  # Extract the prefix of DNS from server, example: https://prefix.example.com/tfs
  local DOMAIN="$(basename $(dirname '$SERVER_URL'))"
  IFS='.' read -r -a DOMAIN <<< "$DOMAIN"
  local readonly DNS_PREFIX="${DOMAIN[0]}"
  
  if [ -d ~/$AZURE_AGENT_HOME ]; then
    echo "Found directory $AZURE_AGENT_HOME. Trying to remove it..."
    if [ -f ~/$AGENT_INSTANCE/svc.sh ]; then
      echo "Found service file. Trying to uninstall.."
      ~/$AGENT_INSTANCE/svc.sh uninstall
      if [ $? = 0 ] && rm "~/Library/LaunchAgents/vsts*"; then
        expectify "sudo rm /Library/LaunchDaemons/vsts*"
        echo "Uninstalled!"
      fi
    fi
    rm -rf ~/$AZURE_AGENT_HOME
    if [ $? = 0 ]; then
      echo "Agent dir successfully removed!"
    fi
  fi

  mkdir -p ~/$AGENT_INSTANCE
  local readonly AZURE_AGENT_TARGZ_FILE="vsts-agent-osx-x64-${AZURE_AGENT_VERSION}.tar.gz"
  while [ ! -f ~/$AZURE_AGENT_HOME/$AZURE_AGENT_TARGZ_FILE ]; do
    echo "Downloading Azure pipeline agent v${AZURE_AGENT_VERSION}..."
    curl -Lk https://vstsagentpackage.azureedge.net/agent/$AZURE_AGENT_VERSION/$AZURE_AGENT_TARGZ_FILE -o ~/$AZURE_AGENT_HOME/$AZURE_AGENT_TARGZ_FILE
    echo "Done!"
    echo "Installing the agent..."  
    cd ~/$AGENT_INSTANCE/
    tar xzf ~/$AZURE_AGENT_HOME/$AZURE_AGENT_TARGZ_FILE
    echo "Done!"
    sleep 1
  done
  
  echo "Configuring the agent instance..."
  #Step 4: Configuring this agent at TFS server
  # Set the timezone before configure
  expectify "sudo systemsetup -settimezone $TIMEZONE"

  #The token need to be generated from the security espace of a builder user https://tfs.copsonic.com/tfs/DefaultCollection/_details/security/tokens)
  #The Agent Pool should be Default for production or TestAgents for testing.
  #The Agent Name must follow this format: CopSonic[Windows/Ubuntu/Mac][0..9]+
  ~/$AGENT_INSTANCE/config.sh --unattended --replace --url $SERVER_URL --auth PAT --token $TOKEN --pool $POOL --agent $AGENT_NAME --work _work

  echo "Done!"

  if [ -f ~/$AGENT_INSTANCE/svc.sh ]; then
    cd ~/$AGENT_INSTANCE/
    echo "Installing agent service..."
    ./svc.sh install
    echo "Done!"
    # Link the .bash_profile file to load all ENV and configurations
    printf '1a\nsource ~/.bash_profile\n.\nw\n' | ed ~/$AGENT_INSTANCE/runsvc.sh
    echo "Agent installed!"
    # Adding automatic mantainance
    crontab -l | { cat; echo "* 4 * * * rm -rf ~/$AGENT_INSTANCE/_work"; } | crontab -
    if [ "$?" == "0" ]; then
      echo "Automatic mantainance routine installed!"
    fi
    # Start the service
    ./svc.sh start

    sleep 10
    echo "Installing Launch daemon"
    expectify "sudo cp $HOME/Library/LaunchAgents/vsts.agent.devops.$AGENT_NAME.plist /Library/LaunchDaemons/"
  else
    echo "Unable to configure the service. Check logs for more info."
  fi
}

echo "Starting script..."

install_xcodeclt() {
  printf '%s\n' "$1"
  echo "Requesting installation..."
  # Download and install Xcode Command Line Tools
  local readonly file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  touch $file
  PROD=$(softwareupdate -l |
    grep "\*.*Command Line" |
    head -n 1 | awk -F"*" '{print $2}' |
    sed -e 's/^ *//' |
    tr -d '\n')
  softwareupdate -i "$PROD" --verbose

  if [ -f $file ]; then
    rm $file
  fi
}

# Check for Xcode Command Line Tools
printf '%s\n' "Looking for Xcode Command Line Tools"
if pkgutil --pkg-info com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then
  printf '%s\n' "CHECKING INSTALLATION"
  count=0
  pkgutil --files com.apple.pkg.CLTools_Executables |
    while IFS= read file; do
      test -e "/${file}" &&
        printf '%s\n' "/${file} - (OK)" || {
        printf '%s\n' "/${file} - (MISSING)"
        ((count++))
      }
    done

  if ((count > 0)); then
    install_xcodeclt "Command Line Tools are not installed properly" || exit 2
    # Provide instructions to remove the CommandLineTools directory
    # and the package receipt then install instructions
  else
    printf '%s\n' "Command Line Tools found, you are good to go!"
  fi
else
  install_xcodeclt "Command Line Tools are not installed" || exit 2
fi

if ! type brew >/dev/null 2>&1; then
  ## Homebrew
  # The esiest way to setup mac is by using a package manager.
  curl -sL -O https://raw.githubusercontent.com/Homebrew/install/master/install
  expectify "ruby install < /dev/null"
  rm ~/install
fi

# Check if Xcode is set to be installed.
if [ "$INSTALL_XCODE" == "1" ]; then
  ## Install XCode-Install gem
  if ! type xcversion >/dev/null 2>&1; then
    echo "Installing xcversion ..."
    ## This will require you provide an Apple Developer Account's credentials
    ## More info at: https://github.com/KrauseFx/xcode-install
    curl -sL -O https://github.com/neonichu/ruby-domain_name/releases/download/v0.5.99999999/domain_name-0.5.99999999.gem

    # Global Variables
    expectify "sudo gem install domain_name-0.5.99999999.gem"
    expectify "sudo gem install --conservative xcode-install"

    rm -f domain_name-0.5.99999999.gem
    echo "Done!"
  fi

  if [ -z "$APPLE_USER" ]; then
    read -p "Apple account's email: " APPLE_USER
  fi

  if [ -z "$APPLE_PASSWORD" ]; then
    read -s -p "Password (for $APPLE_USER): " APPLE_PASSWORD
    echo ""
  fi

  # Install Xcode 10.1
  echo "Xcode versions to install: ${XCODE_VERSIONS[@]}"
  export FASTLANE_USER="$APPLE_USER"
  export FASTLANE_PASSWORD="$APPLE_PASSWORD"
  for i in "${XCODE_VERSIONS[@]}"; do
    expectify "xcversion install $i"
  done
else
  echo "Skipping Xcode installation..."
fi

if ! type brew >/dev/null 2>&1; then
  echo "Unable to find Homebrew installation. Stoping the script..."
  exit 2
fi

##JDK##
#Step 1: Install Oracle Java JDK 8
#The easiest way to install Oracle Java JDK 8 on Mac is via a pkg manager
#brew tap caskroom/versions
#brew tap AdoptOpenJDK/openjdk
#expectify "brew cask install java8"
#expectify "brew cask install adoptopenjdk8"
expectify "brew cask install java"

#Step 2: Add JAVA_HOME into env
echo 'export JAVA_HOME="$(/usr/libexec/java_home)"' >>~/.bash_profile

##XAMARIN##
expectify "brew cask install xamarin-ios"
expectify "brew cask install visual-studio"
expectify "brew install nuget"

if [ "$INSTALL_ANDROID" == "1" ]; then
  ##Android SDK##
  #Step 1: Install SDK
  brew tap homebrew/cask
  expectify "brew cask install android-sdk"
  expectify "brew cask install android-ndk"

  mkdir -p ~/.android/
  touch ~/.android/repositories.cfg
  
  #Step 3: Configure env
  echo 'export ANDROID_SDK_ROOT="/usr/local/share/android-sdk"' >>~/.bash_profile
  echo 'export ANDROID_NDK_HOME="/usr/local/share/android-ndk"' >>~/.bash_profile
  echo 'export ANDROID_HOME="$ANDROID_SDK_ROOT"' >>~/.bash_profile
  echo 'export PATH="$PATH:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools/bin:$ANDROID_SDK_ROOT/platform-tools"' >>~/.bash_profile

  # SymLink sdk for Android
  mkdir -p ~/Library/Android
  ln -s /usr/local/share/android-sdk ~/Library/Android
  mv ~/Library/Android/android-sdk ~/Library/Android/sdk

  ln -s /usr/local/share/android-ndk /usr/local/share/android-sdk
  mv ~/Library/Android/sdk/android-ndk ~/Library/Android/sdk/ndk-bundle
  
  # Install xamarin android
  expectify "brew cask install xamarin-android"
else
  echo "Skipping android installation..."
fi

# Install C++ build tools
expectify "brew install cmake"
expectify "brew install python3"
expectify "brew install ninja"

##Node JS##
#Step 1: Installing Node.js and npm
expectify "brew install node@10"
expectify "brew link --force node@10"
echo 'export PATH="/usr/local/opt/node@10/bin:$PATH"' >>~/.bash_profile

echo 'export PATH="/usr/local/opt/icu4c/bin:$PATH"' >>~/.bash_profile
echo 'export PATH="/usr/local/opt/icu4c/sbin:$PATH"' >>~/.bash_profile

#For compilers to find icu4c you may need to set:
echo 'export LDFLAGS="-L/usr/local/opt/icu4c/lib"' >>~/.bash_profile
echo 'export CPPFLAGS="-I/usr/local/opt/icu4c/include"' >>~/.bash_profile

# Alternatively using Fastlane
expectify "sudo gem install fastlane"
echo 'export PATH="$HOME/.fastlane/bin:$PATH"' >>~/.bash_profile
echo 'export LC_ALL="en_US.UTF-8"' >>~/.bash_profile
echo 'export LANG="en_US.UTF-8"' >>~/.bash_profile
echo 'export LANGUAGE="en_US.UTF-8"' >>~/.bash_profile

# Register xcode-select for remotely use
rule="$USER  ALL=NOPASSWD:/usr/bin/xcode-select"
expectify "sudo /bin/sh -c \"echo $rule >> /etc/sudoers\""

# Install gems
expectify "sudo gem install xcodeproj"

# Install cocoapods
expectify "sudo gem install cocoapods"

#Step 1: Install the prerequisites
expectify "brew install openssl"

# Ensure folder exists on machine
mkdir -p /usr/local/lib/
ln -s /usr/local/opt/openssl/lib/libcrypto.1.0.0.dylib /usr/local/lib/
ln -s /usr/local/opt/openssl/lib/libssl.1.0.0.dylib /usr/local/lib/

#Step 2: Install GIT
expectify "brew install git"
expectify "brew install git-lfs"

#Step 3: Creating an agent
if [ "$CONFIGURE_AZURE_PIPELINE_AGENT" == "1" ]; then
  installAzureAgent
fi

# Heading to home dir
cd ~/
