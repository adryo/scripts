#!/usr/bin/env bash

# Global Variables
AgentLogonPassword=""
APPLE_USER=""
APPLE_PASSWORD=""
# TFS Variables
AGENT_NAME="VM-MacOS-Mojave01"
CONFIGURE_AZURE_PIPELINE_AGENT=1
SERVER_URL=""
TOKEN=""
POOL=""
TIMEZONE=""
XCODE_VERSIONS=(10.1)

# This function is used to initialize the variables according to the supplied values through the scripts arguments
  while [ "$#" -ne 0 ]; do
      ARG="$1"
      shift # get rid of $1, we saved in ARG already
      case "$ARG" in
      --logon-password) 
        AgentLogonPassword=$1
        shift 
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
      --install-xcode) 
      	IN="$(echo -e "$1" | tr -d '[:space:]')"
      	IFS=';' read -ra VERS <<< "$IN"
	for v in "${VERS[@]}"; do
	    # process "$v"
	    XCODE_VERSIONS=("$v" "${XCODE_VERSIONS[@]}")
	done
	shift
      ;;
      --help) 
        echo "Usage:"
        echo ""
        echo "./setup-mac-azure-pipeline-agent.sh [--options]"
        exit 0
      ;;
      *)
        echo "Invalid command or option '$ARG'. Execute --help to see valid arguments."
        exit 1
      ;;
      esac
  done

if [ -z "$AgentLogonPassword" ]; then
    read -s -p "Password (for $USER): " AgentLogonPassword
    echo ""
fi

if [ -z "$APPLE_USER" ]; then
    read -p "Apple account's email: " APPLE_USER
fi

if [ -z "$APPLE_PASSWORD" ]; then
    read -s -p "Password (for $APPLE_USER): " APPLE_PASSWORD
    echo ""
fi

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

# Expect variables
readonly TCL_VERSION="8.6.9"
readonly EXPECT_VERSION="5.45.4"

# VSTS Agent Variables
readonly VSTS_AGENT_VERSION="2.144.2"

echo "Starting script..."

install_xcodeclt() {
    printf '%s\n' "$1"
    # Download and install Xcode Command Line Tools
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
    PROD=$(softwareupdate -l |
    grep "\*.*Command Line" |
    head -n 1 | awk -F"*" '{print $2}' |
    sed -e 's/^ *//' |
    tr -d '\n')
    softwareupdate -i "$PROD" --verbose;
    rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
}

# Check for Xcode Command Line Tools
printf '%s\n' "Looking for Xcode Command Line Tools"
if pkgutil --pkg-info com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then
    printf '%s\n' "CHECKING INSTALLATION"
    count=0
    pkgutil --files com.apple.pkg.CLTools_Executables |
    while IFS= read file
    do
        test -e  "/${file}" &&
        printf '%s\n' "/${file} - (OK)" || { printf '%s\n' "/${file} - (MISSING)"; ((count++)); }
    done
    
    if (( count > 0 )); then
        install_xcodeclt "Command Line Tools are not installed properly" || exit 2
        # Provide instructions to remove the CommandLineTools directory
        # and the package receipt then install instructions
    else 
        printf '%s\n' "Command Line Tools found, you are good to go!"
    fi
else 
    install_xcodeclt "Command Line Tools are not installed" || exit 2
fi

expectify(){
    expect -c "set timeout -1; spawn $1; expect \"Password:*\" {send \"$AgentLogonPassword\n\"; exp_continue} \"RETURN\" {send \"\n\"; exp_continue} $2"
}

install_expect(){
    # Download and install TCL
    readonly TCL_FULL_NAME="tcl${TCL_VERSION}"
    readonly TCL_PKG="${TCL_FULL_NAME}-src.tar.gz"
    # curl -sL -O http://downloads.sourceforge.net/tcl/tcl8.6.9-src.tar.gz --output tcl8.6.9-src.tar.gz
    curl -sL -O http://downloads.sourceforge.net/tcl/$TCL_PKG --output $TCL_PKG
    tar -xzf $TCL_PKG

    # Compilation and installation
    make -C $TCL_FULL_NAME/macosx
    make -C $TCL_FULL_NAME/macosx install INSTALL_ROOT="${HOME}/"

    # Download and install Expect
    readonly EXPECT_FULL_NAME="expect${EXPECT_VERSION}"
    readonly EXPECT_PKG="${EXPECT_FULL_NAME}.tar.gz"
    curl -sL -O https://downloads.sourceforge.net/expect/$EXPECT_PKG --output $EXPECT_PKG
    tar -xzf $EXPECT_PKG

    # Install
    $EXPECT_FULL_NAME/configure --prefix=/usr           \
                --with-tcl=/usr/lib     \
                --enable-shared         \
                --mandir=/usr/share/man \
                --with-tclinclude=/usr/include &&
    make

    # Now, as the root user:
    #sudo make $EXPECT_FULL_NAME/install &&
    expectify "sudo ln -svf $EXPECT_FULL_NAME/libexpect5.45.4.so /usr/lib"
}

if ! type expect >/dev/null 2>&1; then
    echo "'Expect' not installed. Trying to install it automatically..."
    install_expect || exit 2
fi

if ! type brew >/dev/null 2>&1; then
    ## Homebrew
    # The esiest way to setup mac is by using a package manager.
    curl -sL -O https://raw.githubusercontent.com/Homebrew/install/master/install
    expectify "ruby install < /dev/null"
    rm ~/install
fi

## Install XCode-Install gem
## This will require you provide an Apple Developer Account's credentials
## More info at: https://github.com/KrauseFx/xcode-install
curl -sL -O https://github.com/neonichu/ruby-domain_name/releases/download/v0.5.99999999/domain_name-0.5.99999999.gem

# Global Variables
expectify "sudo gem install domain_name-0.5.99999999.gem"
expectify "sudo gem install --conservative xcode-install"

rm -f domain_name-0.5.99999999.gem
# Install Xcode 10.1, 10.0, 9.4
for i in "${XCODE_VERSIONS[@]}"
do
	expectify "xcversion install $i" "\"Username:\" {send \"$APPLE_USER\n\"; exp_continue} \"Password (for *)\" { send \"$APPLE_PASSWORD\n\"; exp_continue}"
done

if ! type brew >/dev/null 2>&1; then
    echo "Unable to find Homebrew installation. Stoping the script..."
    exit 2
fi

##JDK##
#Step 1: Install Oracle Java JDK 8
#The easiest way to install Oracle Java JDK 8 on Mac is via a pkg manager
brew tap caskroom/versions
expectify "brew cask install java8"

#Step 2: Add JAVA_HOME into env
echo "export JAVA_HOME=$(/usr/libexec/java_home)" >> ~/.bash_profile

##Android SDK##
#Step 1: Install SDK
brew tap homebrew/cask 
expectify "brew cask install android-sdk"
expectify "brew cask install android-ndk"

#Installing all build-tools and platforms
sdkmanager --list --verbose | grep -v "^Info:|^\s|^$|^done$" >> out.txt
isAvailable=false
while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ ($line = *"Available"*) || ("$isAvailable" = true) ]]
    then
        isAvailable=true
        if [[ ($line = *"build-tools;"*) || ($line = *"platforms;"*) ]]
        then
            yes | sdkmanager ""$line""
        fi
    fi

done < "out.txt"

sdkmanager --update

#Step 3: Configure env
echo "export ANDROID_SDK_ROOT=/usr/local/share/android-sdk" >> ~/.bash_profile
echo "export ANDROID_NDK_HOME=/usr/local/share/android-ndk" >> ~/.bash_profile
echo "export ANDROID_HOME=\$ANDROID_SDK_ROOT" >> ~/.bash_profile
echo "export PATH=\$PATH:\$ANDROID_SDK_ROOT/emulator:\$ANDROID_SDK_ROOT/tools/bin:\$ANDROID_SDK_ROOT/platform-tools" >> ~/.bash_profile

# SymLink sdk for Android Studio
mkdir -p ~/Library/Android
ln -s /usr/local/share/android-sdk ~/Library/Android
mv ~/Library/Android/android-sdk ~/Library/Android/sdk

ln -s /usr/local/share/android-ndk /usr/local/share/android-sdk
mv ~/Library/Android/android-sdk/android-ndk /usr/local/share/android-sdk/ndk-bundle

##Node JS##
#Step 1: Installing Node.js and npm
expectify "brew install node"

echo 'export PATH="/usr/local/opt/icu4c/bin:$PATH"' >> ~/.bash_profile
echo 'export PATH="/usr/local/opt/icu4c/sbin:$PATH"' >> ~/.bash_profile

#For compilers to find icu4c you may need to set:
echo 'export LDFLAGS="-L/usr/local/opt/icu4c/lib"' >> ~/.bash_profile
echo 'export CPPFLAGS="-I/usr/local/opt/icu4c/include"' >> ~/.bash_profile

# Alternatively using Fastlane
expectify "sudo gem install fastlane"
echo 'export PATH="$HOME/.fastlane/bin:$PATH"' >> ~/.bash_profile
echo "export LC_ALL=en_US.UTF-8" >> ~/.bash_profile
echo "export LANG=en_US.UTF-8" >> ~/.bash_profile
echo "export LANGUAGE=en_US.UTF-8" >> ~/.bash_profile

# Register xcode-select for remotely use
rule="$USER  ALL=NOPASSWD:/usr/bin/xcode-select"
expectify "sudo /bin/sh -c \"echo $rule >> /etc/sudoers\""

# Install SBT
expectify "brew install sbt"

# Install gems
expectify "sudo gem install xcodeproj"

# Install cocoapods
expectify "sudo gem install cocoapods"

##VSTS Agent##
#https://github.com/Microsoft/azure-pipelines-agent/blob/master/README.md
#https://github.com/Microsoft/azure-pipelines-agent/blob/master/docs/start/envosx.md

#Step 1: Install the prerequisites
expectify "brew install openssl"
echo 'export LDFLAGS="-L/usr/local/opt/openssl/lib"' >> ~/.bash_profile
echo 'export CPPFLAGS="-I/usr/local/opt/openssl/include"' >> ~/.bash_profile
echo 'export PATH="/usr/local/opt/openssl/bin:$PATH"' >> ~/.bash_profile
# Ensure folder exists on machine
mkdir -p /usr/local/lib/
ln -s /usr/local/opt/openssl/lib/libcrypto.1.0.0.dylib /usr/local/lib/
ln -s /usr/local/opt/openssl/lib/libssl.1.0.0.dylib /usr/local/lib/

#Step 2: Install GIT
expectify "brew install git"
expectify "brew install git-lfs"

#Step 3: Creating an agent
if [ "$CONFIGURE_AZURE_PIPELINE_AGENT" == "1" ]; then
	readonly VSTS_AGENT_TARGZ_FILE="vsts-agent-osx-x64-${VSTS_AGENT_VERSION}.tar.gz"
	mkdir ~/VSTSAgents
	cd ~/VSTSAgents

	curl https://vstsagentpackage.azureedge.net/agent/$VSTS_AGENT_VERSION/$VSTS_AGENT_TARGZ_FILE --output $VSTS_AGENT_TARGZ_FILE
	mkdir ~/VSTSAgents/agent01 && cd ~/VSTSAgents/agent01
	tar xzf ~/VSTSAgents/$VSTS_AGENT_TARGZ_FILE

	cd ~/VSTSAgents/agent01
	#Step 4: Configuring this agent at TFS server
	# Set the timezone before configure
	expectify "sudo systemsetup -settimezone $TIMEZONE"

	#The token need to be generated from the security espace of a builder user https://tfs.copsonic.com/tfs/DefaultCollection/_details/security/tokens) 
	#The Agent Pool should be Default for production or TestAgents for testing.
	#The Agent Name must follow this format: CopSonic[Windows/Ubuntu/Mac][0..9]+
	~/VSTSAgents/agent01/config.sh --unattended  --url $SERVER_URL --auth PAT --token $TOKEN --pool $POOL --agent $AGENT_NAME --work _work
	~/VSTSAgents/agent01/svc.sh install

	# Link the .bash_profile file to load all ENV and configurations
	printf '1a\nsource ~/.bash_profile\n.\nw\n' | ed ~/VSTSAgents/agent01/runsvc.sh

	# Start the service
	~/VSTSAgents/agent01/svc.sh start
fi
