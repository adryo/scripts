LogonPassword=""
APPLE_USER=""
APPLE_PASSWORD=""
CONFIGURE_AZURE_PIPELINE_AGENT=1

# This function is used to initialize the variables according to the supplied values through the scripts arguments
while [ "$#" -ne 0 ]; do
  ARG="$1"
  shift # get rid of $1, we saved in ARG already
  case "$ARG" in
  --logon-password) 
    LogonPassword=$1
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

if [ -z "$LogonPassword" ]; then
    read -s -p "Password (for $USER): " LogonPassword
    echo ""
fi

if [ -z "$APPLE_USER" ]; then
    read -p "Apple account's email: " APPLE_USER
fi

if [ -z "$APPLE_PASSWORD" ]; then
    read -s -p "Password (for $APPLE_USER): " APPLE_PASSWORD
    echo ""
fi

if [ "$CONFIGURE_AZURE_PIPELINE_AGENT" == "1" ]; then
    # Setup machine
    bash <(curl https://raw.githubusercontent.com/adryo/scripts/develop/setup-mac-azure-pipeline-agent.sh) --skip-agent-config --logon-password $LogonPassword --apple-account $APPLE_USER --apple-password $APPLE_PASSWORD || exit 1

    if [ $? -eq 0 ]; then
      echo "System setup successfully. Proceeding with workstation config..."
      sudo vboxmanage extpack install ./$EXT_PACK --accept-license=$EXT_PACK_LICENSE --replace
    else
      echo "The system wasn't configured. Stoping installation."
      exit 1
    fi
fi

# Install React stuff
npm install -g expo-cli

brew install watchman

npm install -g react-native-cli

# Install Flutter stuff
if ! type flutter >/dev/null 2>&1; then
    echo "Flutter SDK not found. Prepare automatic installation..."
    echo "Downloading SDK package..."
    curl https://storage.googleapis.com/flutter_infra/releases/stable/macos/flutter_macos_v1.0.0-stable.zip -o ~/Downloads/flutter_macos_v1.0.0-stable.zip
    echo "Done!"
    echo "Installing..."
    mkdir -p ~/Library/Flutter/ && cd ~/Library/Flutter/
    unzip ~/Downloads/flutter_macos_v1.0.0-stable.zip
    mv ~/Library/Flutter/flutter ~/Library/Flutter/sdk
    echo 'export FLUTTER_HOME="$HOME/Library/Flutter/sdk"' >> ~/.bash_profile
    echo 'export PATH="$PATH:$FLUTTER_HOME/bin"' >> ~/.bash_profile
    source ~/.bash_profile
    cd ~
    echo "Done!"
    echo "Configuring environment and installing extra resources..."
    brew update
    brew install --HEAD usbmuxd
    brew link usbmuxd
    brew install --HEAD libimobiledevice
    brew install ideviceinstaller

    pod setup
    
    expect -c "set timeout -1; spawn flutter doctor --android-licenses; expect \"(y/N)\" {send: \"y\n\"; exp_continue}"
    brew install ios-deploy
    
    echo "Done!"
fi

flutter doctor
