#!/usr/bin/env bash
#
# DESCRIPTION
# Run macOS 10.14 Mojave in Virtualbox.
# 
###############################################################################
# bash <(curl https://raw.githubusercontent.com/adryo/scripts/develop/setup/macos-vm.sh) all --logon-password S3cr3t --vm-ram-size 6 --ftp-host "ftp://myown.ftp.net/ci_mojave/" --ftp-user user --ftp-password password --vm-rdp-port 3390
# Core parameters #############################################################

# Import globals
source /dev/stdin <<< "$(curl --insecure https://raw.githubusercontent.com/adryo/scripts/develop/setup/globals.sh)" || exit 1

# Global Variables
VM="" # VM takes the name according the installation media file name. Ex. MacOS-Mojave. Change using option --vm-name
VM_HDD_SIZE="102400" # 100 Gb Can be changed using option --vm-hdd-size in Gb, ex. (integer) 100, 120, 80.
VM_RES="1366x768"
VM_RAM="4096" # 4Gb  Can be changed using option --vm-ram-size in Gb, ex. (integer) 6, 8, 4.
VM_CPU="2" # Can be changed using option --vm-cpu
VM_SNAPSHOT_TAG=""
readonly VM_VRAM="128"  

RDP_PORT="3389" # Can be changed using option --vm-rdp-port
SSH_PORT="2222" # Can be changed using option --vm-ssh-port

DOWNLOAD_MODE="ftp"
FTP_USER="" # Can be set using --ftp-user
FTP_PASSWORD="" # Can be set using --ftp-password
FTP_HOST="" # Can be set using --ftp-host
FTP_DIR="" # Can be set using --ftp-dir

# Other variables
PREPARATION_TIMEOUT=1800 # 30 minutes
readonly EXT_PACK_LICENSE="56be48f923303c8cababb0bb4c478284b688ed23f16d775d729b89a2e8e5f9eb"
readonly IP_ADDRESS=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
readonly PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin"
readonly SCRIPTPATH="$(
  cd "$(dirname "$0")" || exit
  pwd -P
)"

MEDIA_DIR="$HOME/installer/"

# Array to collect the tasks to execute
tasks=()

# This function is used to initialize the variables according to the supplied values through the scripts arguments
while [ "$#" -ne 0 ]; do
  ARG="$1"
  shift # get rid of $1, we saved in ARG already
  case "$ARG" in
  --ftp-host) 
    FTP_HOST=$1
    shift 
  ;;
  --ftp-user) 
    FTP_USER=$1
    shift 
  ;;
  --ftp-password) 
    FTP_PASSWORD=$1
    shift 
  ;;
  --ftp-dir) 
    FTP_DIR=$1
    shift 
  ;;
  --scp-host) 
    FTP_HOST=$1
    shift 
  ;;
  --scp-user) 
    FTP_USER=$1
    shift 
  ;;
  --scp-password) 
    FTP_PASSWORD=$1
    shift 
  ;;
  --scp-dir) 
    FTP_DIR=$1
    shift 
  ;;
  --vm-name) 
    VM=$1
    shift 
  ;;
  --vm-hdd-size) 
    VM_HDD_SIZE=$(expr $1 \* 1024)
    shift 
  ;;
  --vm-ram-size) 
    VM_RAM=$(expr $1 \* 1024)
    shift 
  ;;
  --vm-cpu) 
    VM_CPU=$1
    shift 
  ;;
  --vm-rdp-port) 
    RDP_PORT=$1
    shift 
  ;;
  --vm-ssh-port) 
    SSH_PORT=$1
    shift 
  ;;
  --vm-snapshot-tag) 
    VM_SNAPSHOT_TAG=$1
    shift 
  ;;
  --preparation-timeout) 
    PREPARATION_TIMEOUT=$(expr $1 \* 60)
    shift 
  ;;
  --download-mode) 
    DOWNLOAD_MODE=$1
    shift 
  ;;
  --help) 
    echo "Usage:"
    echo ""
    echo "./mascos-vm.sh [task][task] [--options]"
    echo ""
    echo "Available tasks:"
    echo "check: Check if the dependencies are installed correctly and if the hardware supports virtualization to proceed with the VM creation."
    echo "stash: Removes a previously created VM."
    echo "info: Returns the info of the VM if exists."
    echo "snapshot: Creates an instant snapshot of the VM. Use the option --vm-snapshot-tag to customize the identification of the snapshot."
    echo "run: Runs the VM if it is stopped."
    echo "attach: Attaches the installation and boot loader medias ISO files. It’s used internally in the prepare command."
    echo "detach: Detaches the installation media, letting the VM run only by the main HDD media."
    echo "prepare: Executes the VM to prepare it for installation."
    echo "stop: Stops the VM execution if it is running."
    echo "create: Creates a VM if there is no one created. When using this command is recommended execute the stash one before, to make sure the deletion of any previous VM configuration."
    echo "install: This command installs Virtual Box from the repo via command line. It may require sudo permission. Check option --logon-password for unattended execution."
    echo "all: From a fresh installation state, this command executes a check, create and prepare commands in that order to make a clean VM configuration and proceed to prepare MacOS installation."
    echo ""
    echo "Available options:"
    echo "--help: Display the usage tips plus tasks and options descriptions."
    echo "--logon-password: Sets the server credential for the script to act as sudo user while needed."
    echo "--download-mode: Sets the download mode between 'ftp' or 'scp'. Use --ftp-* or --scp-* options to provide credentials and host values. Default mode is FTP."
    echo "--preparation-timeout: Sets timeout (in minutes) to await in preparation mode. Default is (30) minutes."
    echo "--ftp-user: Sets the ftp user's name to download the installation media if they are not present in the ubuntu host."
    echo "--ftp-password: Sets the ftp user's password to download the installation media if they are not present in the ubuntu host."
    echo "--ftp-host: Sets the ftp host name to download the installation media if they are not present in the ubuntu host. Must be set in this format 'ftp://host-name/'."
    echo "--ftp-dir: Sets the ftp dir where the ISO files are hosted, to download them if they are not present in the ubuntu host. Must be set in this format 'dirname/'."
    echo "--scp-user: Sets the scp user's name to download the installation media if they are not present in the ubuntu host."
    echo "--scp-password: Sets the scp user's password to download the installation media if they are not present in the ubuntu host."
    echo "--scp-host: Sets the scp host name to download the installation media if they are not present in the ubuntu host. Must be set in this format 'dns.example.com' or IP address."
    echo "--scp-dir: Sets the scp dir where the ISO files are hosted, to download them if they are not present in the ubuntu host. Must be set in this format 'dirname/'."
    echo "--vm-name: Sets the name of the VM. By default VM takes the name according the installation media file name. Ex. MacOS-Mojave."
    echo "--vm-hdd-size: Sets the amount (integer) of Gigabytes to set in the VM's HDD. Default to 100 Gb."
    echo "--vm-ram-size: Sets the amount (integer) of Gigabytes to set in VM's RAM. Default to 4 Gb."
    echo "--vm-cpu: Sets the amount of CPU to set in the VM's instance. Default is 2."
    echo "--vm-rdp-port: Sets the port to connect via RDP to the VM's instance while it's running. Default is 3389."
    echo "--vm-ssh-port: Sets the port to connect via SSH to the VM's instance while it's running. Default is 2222."
    echo "--vm-snapshot-tag: Sets a custom tag identifier for the snapshot. Only usable when executing snapshot task."
    exit 0
  ;;
  all|check|info|run|stop|stash|snapshot|attach|detach|install|create|prepare)
    tasks+=($ARG)
  ;;
  *)
    echo "Invalid command or option '$ARG'. Execute --help to see valid arguments."
    exit 1
  ;;
  esac
done

if [ -z "$tasks" ]; then
  echo "No task to execute, the script will do nothing. Please use the option --help to see usage."
  exit 1
fi

while [ -z "$VM" ]; do
  read -p "Enter VM's name or press Ctrl+c to cancel the installation: " VM
done

readonly FILE_LOG="${MEDIA_DIR}${VM}Installation.log"
# Logging #####################################################################
if [ ! -f "$FILE_LOG" ]; then
  touch $FILE_LOG
fi
###############################################################################

# Define methods ##############################################################
debug() {
  printf '%s\n' "DEBUG: $1"
  log "$1"
}

error() {
  printf '%s\n' "ERROR: $1"
  log "$1"
}

info() {
  printf '%s\n' "$1"
  log "$1"
}

result() {
  printf '%s\n' "$1"
  log "$1"
}

log() {
  datestring="$(date +'%Y-%m-%d %H:%M:%S')"
  printf '%s\n' "[$datestring] $1" >> "$FILE_LOG"
}

downloadMedias() {
  if [ -z "$FTP_USER" ]; then
      read -p "Username: " FTP_USER
  fi

  if [ -z "$FTP_PASSWORD" ]; then
      read -s -p "Password (for $FTP_USER): " FTP_PASSWORD
      echo ""
  fi

  if [ -z "$FTP_HOST" ]; then
      read -p "Server's url: " FTP_HOST
  fi

  local dowloaded=0
  echo "Download mode is set to: '$DOWNLOAD_MODE'"
  echo "Connecting to ${FTP_HOST}${FTP_DIR}, with credentials: $FTP_USER"
  if [ -z "$DOWNLOAD_MODE" ] || [ "ftp" == "$DOWNLOAD_MODE" ]; then
    wget --ftp-user=$FTP_USER --ftp-password=$FTP_PASSWORD "${FTP_HOST}${FTP_DIR}*" --directory-prefix=$MEDIA_DIR
    if [ $? -eq 0 ]; then
      dowloaded=1
    fi
  else 
    if [ "scp" == "$DOWNLOAD_MODE" ]; then
      run_expect "scp -r $FTP_USER@$FTP_HOST:${FTP_DIR}MacOS-*.iso* $MEDIA_DIR;" "$FTP_PASSWORD"
      if [ $? -eq 0 ]; then
        dowloaded=1
      fi
    fi
  fi

  if [ "$downloaded" == "1" ]; then
      echo "Done! Proceeding with installation..."
  else
      echo "Unable to download media. Stoping installation."
      exit 1
  fi
}

# Extract ISO name
if [ ! -d "$MEDIA_DIR" ] && mkdir -p "$MEDIA_DIR" || [ -z "$(find $MEDIA_DIR -maxdepth 1 -type f -name '*.iso.cdr' -print -quit)" ]; then
  echo "ISO files not found, attempting to download them..."
  
  # Request to download the ISO files.
  downloadMedias
fi

echo "Selected profile for setup: "
echo "* VM's name: $VM"
echo "* HDD Size: $((VM_HDD_SIZE / 1024)) Gb"
echo "* VM RAM: $((VM_RAM / 1024)) Gb"
echo "* VM CPU: $VM_CPU"
echo "* RDP port: $RDP_PORT"
echo "* SSH port: $SSH_PORT"

name="$(find $MEDIA_DIR -maxdepth 1 -type f -name '*.iso.cdr' -print -quit)"
name=${name##*/}
name=${name%.*.*};

if [ -z $name ]; then
  echo "No installation media found. Unable to install, stopping script..."
  exit 2
fi

readonly ISO_NAME="$name"

readonly DST_DIR="$HOME/VirtualBox VMs/"
readonly VM_DIR="$DST_DIR$VM"
readonly DST_VOL="/Volumes/$VM"
readonly DST_CLOVER="${MEDIA_DIR}${ISO_NAME}-Clover"
readonly DST_ISO="${MEDIA_DIR}$ISO_NAME.iso.cdr"
###############################################################################

runChecks() {
  info "Running checks (around 1 second)..." 0

  if [[ "$GLOBAL_PLATFORM_OS" == 'Linux' ]]; then
    if ! type modprobe >/dev/null 2>&1; then
      error "'msr-tools' noµt installed. Trying to install automatically..." 0
      expectify "sudo apt install msr-tools -y"
    fi

    # Read Virtualization
    expectify "sudo modprobe msr"
    expect_digit "sudo rdmsr 0x3a" "$CURRENT_LOGON_PASSWORD"
    VT_CHECK=$?

    info "Checking virtualization: $VT_CHECK"

    if [ \("$VT_CHECK" = ""\) -o \("$VT_CHECK" = "0"\) ]; then
      result "'Vt-x' is not supported in this machine. Please use a different hardware." 0
      exit 1;
    fi

    if [ "$VT_CHECK" = "1" ]; then
      result "'Vt-x' is supported but is currently disabled. Please enable it in the BIOS configuration and run this script again." 0
      exit 1;
    fi
  fi

  if ! type vboxmanage >/dev/null 2>&1; then
    result "'VBoxManage' not installed. Trying to install automatically..." 0
    installVBox || exit 2
  fi
}

installVBox(){
  info "Attempting to obtain VirtualBox keys..."
  wget https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- >> oracle_vbox_2016.asc
  expectify "sudo apt-key add oracle_vbox_2016.asc"
  wget https://www.virtualbox.org/download/oracle_vbox.asc -O- >> oracle_vbox.asc
  expectify "sudo apt-key add oracle_vbox.asc"
  result "Done!"
  info "Setting VBox repo source..."
  # Register virtual-box source
  rule="deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib"
  expectify "sudo /bin/sh -c \"echo $rule >> /etc/apt/sources.list.d/virtualbox.list\""
  result "Done!"

  info "Installing Virtual Box requirements..."
  expectify "sudo apt update"
  expectify "sudo apt -y install gcc make linux-headers-$(uname -r) dkms"
  result "Done!"

  info "Installing Virtual Box package..."
  expectify "sudo apt update"
  expectify "sudo apt install virtualbox-5.2 -y"
  result "Done!"

  VB_VERSION="$(virtualbox --help | head -n 1 | awk '{print $NF}')" # Gets the version of Virtualbox
  EXT_PACK="Oracle_VM_VirtualBox_Extension_Pack-$VB_VERSION.vbox-extpack"

  info "Installed version $VB_VERSION." 0

  if [ ! -f "./$EXT_PACK" ]; then
    info "Attempting to download VirtualBox extensions pack version $VB_VERSION" 0
    wget "http://download.virtualbox.org/virtualbox/$VB_VERSION/$EXT_PACK"

    if [ $? -eq 0 ]; then
        result "Extension packs downloaded. Proceeding with installation..."
        expectify "sudo vboxmanage extpack install ./$EXT_PACK --accept-license=$EXT_PACK_LICENSE --replace"
    else
        result "Unable to download Extension Packs. Stoping installation."
        exit 1
    fi
  fi

  # Add user to vboxusers group
  expectify "sudo usermod -a -G vboxusers $USER"

  expectify "sudo timeshift --create --comments 'Virtual Box installed'" #Create a restore point
}

createVM() {
  if [ ! -e "$VM_DIR" ]; then
    mkdir -p "$VM_DIR"
  fi
  info "Creating VM HDD '$VM_DIR/$VM.vdi' (around 5 seconds)..." 90
  if [ ! -e "$VM_DIR/$VM.vdi" ]; then
    result "Done!"
    vboxmanage createhd --filename "$VM_DIR/$VM.vdi" --variant Standard --size "$VM_HDD_SIZE"
  else
    result "already exists." 0
  fi
  info "Creating VM '$VM' (around 2 seconds)..." 99
  if ! vboxmanage showvminfo "$VM" >/dev/null 2>&1; then
    result "Done!"
    vboxmanage createvm --register --name "$VM" --ostype MacOS1013_64
    vboxmanage modifyvm "$VM" --usbxhci on --memory "$VM_RAM" --vram "$VM_VRAM" --cpus "$VM_CPU" --firmware efi --chipset ich9 --mouse usbtablet --keyboard usb    
    vboxmanage setextradata "$VM" "CustomVideoMode1" "${VM_RES}x32"    
    vboxmanage setextradata "$VM" VBoxInternal2/EfiGraphicsResolution "$VM_RES"    
    vboxmanage storagectl "$VM" --name "SATA Controller" --add sata --controller IntelAHCI --hostiocache on
    vboxmanage storageattach "$VM" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --nonrotational on --medium "$VM_DIR/$VM.vdi"
  
    # vboxmanage storageattach "$VM" --storagectl "SATA Controller" --port 2 --device 0 --type dvddrive --medium none
    # vboxmanage storageattach "MacOS-Mojave" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium none

    # Add codecs
    vboxmanage modifyvm "$VM" --cpuidset 00000001 000106e5 00100800 0098e3fd bfebfbff
    vboxmanage setextradata "$VM" "VBoxInternal/Devices/efi/0/Config/DmiSystemProduct" "iMac11,3"
    vboxmanage setextradata "$VM" "VBoxInternal/Devices/efi/0/Config/DmiSystemVersion" "1.0"
    vboxmanage setextradata "$VM" "VBoxInternal/Devices/efi/0/Config/DmiBoardProduct" "Iloveapple"
    vboxmanage setextradata "$VM" "VBoxInternal/Devices/smc/0/Config/DeviceKey" "ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
    vboxmanage setextradata "$VM" "VBoxInternal/Devices/smc/0/Config/GetKeyFromRealSMC" 1
    # Configure Remote connection
    vboxmanage modifyvm "$VM" --vrde on --vrdeport $RDP_PORT
    vboxmanage modifyvm "$VM" --vrdemulticon on # Multi-connections

    # Enable Virtual Machine SSH door
    vboxmanage modifyvm "$VM" --nic1 NAT
    vboxmanage modifyvm "$VM" --natpf1 "guestssh,tcp,,$SSH_PORT,,22"
  else
    result "already exists."
  fi
}

runVM() {
  info "Starting VM '$VM' (3 minutes in the VM)..." 100
  if ! vboxmanage showvminfo "$VM" | grep "State:" | grep -i running >/dev/null; then
    result "Done!"
    vboxmanage startvm "$VM" --type headless

    if [ $? -eq 0 ]; then
        result "Virtual Machine running..."
    else
        result "Unable to start Virtual Machine, probably it means that virtualization is not enabled."
        exit 1
    fi
  else
    result "already running."
  fi
}

stopVM(){
  vboxmanage controlvm "$VM" poweroff soft || true
}

attach(){
  info "Attaching ISO files..." 0
  state="$(vboxmanage showvminfo $VM | grep 'State:')"
  if [[ $state =~ "running" ]]; then
    stopVM
    info "Stopping VM before attach the media..." 0
  fi

  vboxmanage storageattach "$VM" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "$DST_CLOVER.iso"
  vboxmanage storageattach "$VM" --storagectl "SATA Controller" --port 2 --device 0 --type dvddrive --medium "$DST_ISO"
  result "Done!"
}

detach(){
  info "Detaching ISO files..." 0
  state="$(vboxmanage showvminfo $VM | grep 'State:')"
  if [[ $state =~ "running" ]]; then
    stopVM
    info "Stopping VM before detach the medias..." 0
  fi

  vboxmanage storageattach "$VM" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium none 
  vboxmanage storageattach "$VM" --storagectl "SATA Controller" --port 2 --device 0 --type dvddrive --medium none
  result "Done!"
}

# This step runs inmediatly after the vm creation 
prepareOS(){
  # Attach the installation media
  attach

  # Run the VM
  runVM

  # While the VM installer is prepared, check the status of the VM until it shutdowns.
  echo "Prepare the installation. DO NOT end this script execution. Connect via RDP to '$IP_ADDRESS:$RDP_PORT' and execute the '/Volume/NO\ NAME/prepare.sh' script to be prepared, then this script will continue automatically." >&4
  state="running"
  SECONDS=0

  while [[ SECONDS -lt $PREPARATION_TIMEOUT ]] && [[ $state =~ "running" ]]; do
    # Update state
    state="$(vboxmanage showvminfo $VM | grep 'State:')"
    sleep 10
  done

  # Detaching the installation medias
  detach
  
  info "Restarting the VM after changes. Installing OS..." 0
  runVM

  # Let the installation proceed and restart after 40 minutes
  state="running"
  SECONDS=0

  while [[ SECONDS -lt 3600 ]] && [[ $state =~ "running" ]]; do
    # Update state
    state="$(vboxmanage showvminfo $VM | grep 'State:')"
    sleep 60
  done

  # Restart the VM after installation was done.
  stopVM && runVM

  runSnapshot

  result "You are good to go and complete the configuration!"
}

runSnapshot(){
  NOW=`date +"%m-%d-%Y%T"`
  SNAPSHOT_DESCRIPTION="Snapshot taken on $NOW"

  vboxmanage snapshot $VM take "${name}_${NOW}" --description "${VM_SNAPSHOT_TAG}$SNAPSHOT_DESCRIPTION"
}

cleanup() {
  local err="${1:-}"
  local line="${2:-}"
  local linecallfunc="${3:-}"
  local command="${4:-}"
  local funcstack="${5:-}"

  if [[ $err -ne "0" ]]; then
    debug "line $line - command '$command' exited with status: $err."
    debug "In $funcstack called at line $linecallfunc."
    debug "From function ${funcstack[0]} (line $linecallfunc)."
    error "Look at $FILE_LOG for details. Press enter in the terminal when done..."
    read -r
  fi
}

main() {
  while [ "$#" -ne 0 ]; do
    ARG="$1"
    shift # get rid of $1, we saved in ARG already
    case "$ARG" in
      check) runChecks ;;
      stash) vboxmanage unregistervm --delete "$VM" || true ;;
      info) echo "$(vboxmanage showvminfo $VM)" || true ;;
      snapshot) runSnapshot ;;
      run) runVM ;;
      attach) attach ;;
      detach) detach ;;
      prepare) prepareOS ;;
      stop) stopVM ;;
      create) createVM ;;
      install) installVBox ;;
      all) runChecks && createVM && prepareOS ;;
    esac
  done
}
###############################################################################

# Run script ##################################################################
[[ ${BASH_SOURCE[0]} == "${0}" ]] && trap 'cleanup "${?}" "${LINENO}" "${BASH_LINENO}" "${BASH_COMMAND}" $(printf "::%s" ${FUNCNAME[@]:-})' EXIT && main "${tasks[@]}"
###############################################################################
