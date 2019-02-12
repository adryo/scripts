#!/usr/bin/env bash
# Variables
CURRENT_LOGON_PASSWORD=""

# Globals
readonly GLOBAL_PLATFORM_OS="$(uname -s)"

# Expect REGEX
readonly regex_password="*?assword*:*"

# Extracting --logon-password
found_logon_password=0
for arg do
  shift
  if [ ! -z $found_logon_password ]; then
    CURRENT_LOGON_PASSWORD="$arg"
    found_logon_password=0
    continue
  fi
  if [ "$arg" = "--logon-password" ]; then
    found_logon_password=1
    continue
  fi
  set -- "$@" "$arg"
done

# Installs expect if is not found in the environment
install_expect() {
    echo "Requested expect installtion..."
    if [ "$GLOBAL_PLATFORM_OS" == "Darwin" ]; then
        # Expect variables
        local TCL_VERSION="8.6.9"
        local EXPECT_VERSION="5.45.4"
        # Download and install TCL
        local TCL_FULL_NAME="tcl${TCL_VERSION}"
        local TCL_PKG="${TCL_FULL_NAME}-src.tar.gz"

        echo "Downloading dependency $TCL_PKG..."
        # curl -sL -O http://downloads.sourceforge.net/tcl/tcl8.6.9-src.tar.gz --output tcl8.6.9-src.tar.gz
        curl -sL -O http://downloads.sourceforge.net/tcl/$TCL_PKG --output $TCL_PKG
        echo "Done!"
        echo "Unpacking $TCL_PKG ..."
        tar -xzf $TCL_PKG
        echo "Done!"

        echo "Compiling dependency $TCL_PKG..."
        # Compilation and installation
        make -C $TCL_FULL_NAME/macosx
        make -C $TCL_FULL_NAME/macosx install INSTALL_ROOT="${HOME}/"
        echo "Done!"

        # Download and install Expect
        local EXPECT_FULL_NAME="expect${EXPECT_VERSION}"
        local EXPECT_PKG="${EXPECT_FULL_NAME}.tar.gz"
        echo "Downloading expect $EXPECT_PKG..."
        curl -sL -O https://downloads.sourceforge.net/expect/$EXPECT_PKG --output $EXPECT_PKG
        echo "Done!"
        echo "Unpacking $EXPECT_PKG ..."
        tar -xzf $EXPECT_PKG
        echo "Done!"

        echo "Compiling $EXPECT_PKG..."
        # Install
        $EXPECT_FULL_NAME/configure --prefix=/usr \
            --with-tcl=/usr/lib \
            --enable-shared \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include &&
            make

        echo "Installing expect..."
        # Now, as the root user:
        #sudo make $EXPECT_FULL_NAME/install &&
        expectify "sudo ln -svf $EXPECT_FULL_NAME/libexpect5.45.4.so /usr/lib"
    else
        if [ "$GLOBAL_PLATFORM_OS" == "Linux" ]; then
            echo "Installing expect..."
            sudo rm /var/lib/apt/lists/lock
            sudo rm /var/cache/apt/archives/lock
            sudo rm /var/lib/dpkg/lock
            sudo apt install expect -y
        fi
    fi

    return 0
}

# Check if expect is installed
check_expect() {
    if ! type expect >/dev/null 2>&1; then
        printf '%s\n' "Expect not installed!"
        return 1
    fi

    return 0
}

# Check if expect exists and if not, tries to install it automatically.
check_install_expect() {
    if ! check_expect; then
        echo "Attempting to install automatically..."
        install_expect

        if [ $? -eq 0 ]; then
            echo "Installation successfully..."
        else
            echo "Unable to install expect."
            return 1
        fi
    fi

    return 0
}

# Runs expect command to the supplied command, with the password and you can attach whatever rules you want.
# $1 command
# $2 password
# $3 rules
run_expect() {
    check_install_expect

    if [ $? -eq 0 ]; then
        expect -c "set timeout -1; spawn $1; expect $regex_password {send \"$2\n\"; exp_continue} \"RETURN\" {send \"\n\"; exp_continue} \"(yes/no)?\" {send \"yes\n\"; exp_continue} $3"
    else
        echo "Unable to use expect."
        exit 1
    fi
}

# Returns a digit resulting of the supplied command and password.
expect_digit(){
    check_install_expect
    if [ $? -eq 0 ]; then
        local regex_digit="\[0-9]"
        return $(expect -c "set timeout -1; log_user 0; spawn $1; expect $regex_password {send \"$2\r\n\"; exp_continue} $regex_digit {puts \$expect_out(0,string)}")
    else
        echo "Unable to use expect."
        exit 1
    fi
    
    return 0
}

# Runs expect providing the CURRENT_LOGON_PASSWORD value as password.
expectify() {
    if [ -z "$CURRENT_LOGON_PASSWORD" ]; then
        read -s -p "Password (for $USER): " CURRENT_LOGON_PASSWORD
        echo ""
    fi

    run_expect "$1" "$CURRENT_LOGON_PASSWORD" "$2"
}
