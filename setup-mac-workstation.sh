
# Setup machine

bash <(curl https://raw.githubusercontent.com/adryo/scripts/develop/setup-mac-azure-pipeline-agent.sh) --logon-password $LogonPassword --apple-account $AppleUser --apple-password $ApplePassword

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
