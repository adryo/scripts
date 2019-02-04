  #!/usr/bin/env bash
  #
  # DESCRIPTION
  # Run macOS 10.14 Mojave in Virtualbox.
  # 
  ###############################################################################
  # bash <(curl https://raw.githubusercontent.com/adryo/scripts/develop/setup/macos-vm.sh) --logon-password S3cr3t --vm-ram-size 6 --ftp-host "ftp://myown.ftp.net/ci_mojave/" --ftp-user user --ftp-password password --vm-rdp-port 3390
  # Core parameters #############################################################
  AgentLogonPassword=""

  VM="" # VM takes the name according the installation media file name. Ex. MacOS-Mojave. Change using option --vm-name
  VM_HDD_SIZE="102400" # 100 Gb Can be changed using option --vm-hdd-size in Gb, ex. (integer) 100, 120, 80.
  VM_RES="1366x768"
  VM_RAM="4096" # 4Gb  Can be changed using option --vm-ram-size in Gb, ex. (integer) 6, 8, 4.
  VM_CPU="2" # Can be changed using option --vm-cpu

  RDP_PORT="3389" # Can be changed using option --vm-rdp-port
  SSH_PORT="2222" # Can be changed using option --vm-ssh-port

  FTP_USER="" # Can be set using --ftp-user
  FTP_PASSWORD="" # Can be set using --ftp-password
  FTP_HOST="" # Can be set using --ftp-host
  FTP_DIR="" # Can be ser using --ftp-dir

  # Other variables
  readonly VM_VRAM="128"
  readonly PREPARATION_TIMEOUT=1800 # 30 minutes
  readonly EXT_PACK_LICENSE="56be48f923303c8cababb0bb4c478284b688ed23f16d775d729b89a2e8e5f9eb"

  readonly PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin"
  readonly SCRIPTPATH="$(
    cd "$(dirname "$0")" || exit
    pwd -P
  )"

  # Idenfity platform
  PLATFORM=`uname`
  MEDIA_DIR="$HOME/installer/"

  # This function is used to initialize the variables according to the supplied values through the scripts arguments
  initialize() {
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
          --logon-password) 
            AgentLogonPassword=$1
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
          --help) 
            echo "Possible arguments:"
            echo "--help: Display this option descrition."
            echo "--logon-password: Sets the server credential for the script to act as sudo user while needed."
            echo "--ftp-user: Sets the ftp user's name to download the installation media if they are not present in the ubuntu host."
            echo "--ftp-password: Sets the ftp user's password to download the installation media if they are not present in the ubuntu host."
            echo "--ftp-host: Sets the ftp host's name to download the installation media if they are not present in the ubuntu host. Most be set in this format 'ftp://host-name/'."
            echo "--ftp-dir: Sets the ftp dir where the ISO files are hosted, to download them if they are not present in the ubuntu host. Most be set in this format 'dirname/'."
            echo "--vm-name: Sets the name of the VM. By default VM takes the name according the installation media file name. Ex. MacOS-Mojave."
            echo "--vm-hdd-size: Sets the amount (integer) of Gigabytes to set in the VM's HDD. Default to 100 Gb."
            echo "--vm-ram-size: Sets the amount (integer) of Gigabytes to set in VM's RAM. Default to 4 Gb."
            echo "--vm-cpu: Sets the amount of CPU to set in the VM's instance. Default is 2."

            echo "--vm-rdp-port: Sets the port to connect via RDP to the VM's instance while it's running. Default is 3389."
            echo "--vm-ssh-port: Sets the port to connect via SSH to the VM's instance while it's running. Default is 2222."
            exit 0
          ;;
          *)
            echo "Invalid option '$ARG'. Execute --help to see valid arguments."
            exit 1
          ;;
          esac
      done
  }

  # Request initialization
  ARGS=$@
  initialize $ARGS

    # Extract ISO name
  if [ ! -d "$MEDIA_DIR" ] || [[ "" == "$(find $MEDIA_DIR -maxdepth 1 -type f -name '*.iso.cdr' -print -quit)" ]]; then
    echo "ISO files not found, attempting to download them."
    if [ -z "$FTP_USER" ]; then
        read -p "Apple account's email: " FTP_USER
    fi

    if [ -z "$FTP_PASSWORD" ]; then
        read -s -p "Password (for $FTP_USER): " FTP_PASSWORD
        echo ""
    fi

    if [ -z "$FTP_HOST" ]; then
        read -p "FTP server's url: " FTP_HOST
    fi

    wget --ftp-user=$FTP_USER --ftp-password=$FTP_PASSWORD "${FTP_HOST}${FTP_DIR}*" --directory-prefix=$MEDIA_DIR

    if [ $? -eq 0 ]; then
        echo "ISO files downloaded. Proceeding with installation..."
    else
        echo "Unable to download media. Stoping installation."
        exit 1
    fi
  fi

  if [ -z "$VM" ]; then
    name="$(find $MEDIA_DIR -maxdepth 1 -type f -name '*.iso.cdr' -print -quit)"
    name=${name##*/}
    name=${name%.*.*};
    VM="$name"
  fi

  echo "Selected profile for setup: "
  echo "* VM's name: $VM"
  echo "* HDD Size: $((VM_HDD_SIZE / 1024)) Gb"
  echo "* VM RAM: $((VM_RAM / 1024)) Gb"
  echo "* VM CPU: $VM_CPU"
  echo "* RDP port: $RDP_PORT"
  echo "* SSH port: $SSH_PORT"

  readonly DST_DIR="$HOME/VirtualBox VMs/"
  readonly VM_DIR="$DST_DIR$VM"
  readonly DST_CLOVER="$MEDIA_DIR/${VM}-Clover"
  readonly DST_VOL="/Volumes/$VM"
  readonly DST_ISO="$MEDIA_DIR/$VM.iso.cdr"
  readonly FILE_LOG="$SCRIPTPATH/${VM}Installation.log"
  ###############################################################################
  # Logging #####################################################################
  if [ ! -f "$FILE_LOG" ]; then
    touch $FILE_LOG
  fi
  exec 3>&1
  exec 4>&2
  exec 1>>"$FILE_LOG"
  exec 2>&1
  ###############################################################################

  # Define methods ##############################################################
  debug() {
    echo "DEBUG: $1" >&3
    log "$1"
  }

  error() {
    echo "ERROR: $1" >&4
    log "$1"
  }

  info() {
    echo -n "$1" >&3
    log "$1"
  }

  result() {
    echo "$1" >&3
    log "$1"
  }

  log() {
    datestring="$(date +'%Y-%m-%d %H:%M:%S')"
    echo "[$datestring] $1" >> "$FILE_LOG"
  }

  runChecks() {
    info "Running checks (around 1 second)..." 0
    result "."

    if [[ "$PLATFORM" == 'Linux' ]]; then
      if ! type modprobe >/dev/null 2>&1; then
        error "'msr-tools' not installed. Trying to install automatically..."
        sudo apt install msr-tools -y
      fi

      VT_CHECK="$(sudo modprobe msr && sudo rdmsr 0x3a)"

      echo "Checking virtualization: $VT_CHECK"

      if [ \("$VT_CHECK" = ""\) -o \("$VT_CHECK" = "0"\) -o \("$VT_CHECK" = "5"\)]; then
        error "'Vt-x' is not supported in this machine. Please use a different hardware."
        exit 1;
      fi

      if [ "$VT_CHECK" = "1" ]; then
        error "'Vt-x' is supported but is currently disabled. Please enable it in the BIOS configuration and run this script again."
        exit 1;
      fi
    fi

    if ! type vboxmanage >/dev/null 2>&1; then
      error "'VBoxManage' not installed. Trying to install automatically..."
      installVBox || exit 2
    fi
  }

  expectify(){
    if [ -z "$AgentLogonPassword" ]; then
      read -s -p "Password (for $USER): " AgentLogonPassword
      echo ""
    fi
    expect -c "set timeout -1; spawn $1; expect \"Password:*\" {send \"$AgentLogonPassword\r\n\"; exp_continue} $2" || exit 2
  }

  installVBox(){
    info "Attempting to download VirtualBox"
    expectify "wget https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -"
    expectify "wget https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -"
    info "Downloaded VirtualBox repos asc files"
    expectify "sudo sh -c 'echo \"deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib\" >> /etc/apt/sources.list.d/virtualbox.list'"
    expectify "sudo apt update && sudo apt-get -y install gcc make linux-headers-$(uname -r) dkms"
    expectify "sudo apt update && sudo apt-get install virtualbox-5.2 -y"
    VB_VERSION="$(virtualbox --help | head -n 1 | awk '{print $NF}')" # Gets the version of Virtualbox
    EXT_PACK="Oracle_VM_VirtualBox_Extension_Pack-$VB_VERSION.vbox-extpack"

    if [ ! -f "./$EXT_PACK" ]; then
      info "Attempting to download VirtualBox extensions pack version $VB_VERSION"
      wget "http://download.virtualbox.org/virtualbox/$VB_VERSION/$EXT_PACK"

      expectify "sudo vboxmanage extpack install ./$EXT_PACK --accept-license=$EXT_PACK_LICENSE --replace"
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
      result "."
      vboxmanage createhd --filename "$VM_DIR/$VM.vdi" --variant Standard --size "$VM_HDD_SIZE"
    else
      result "already exists."
    fi
    info "Creating VM '$VM' (around 2 seconds)..." 99
    if ! vboxmanage showvminfo "$VM" >/dev/null 2>&1; then
      result "."
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
      result "."
      vboxmanage startvm "$VM" --type headless
    else
      result "already running."
    fi
  }

  stopVM(){
    vboxmanage controlvm "$VM" poweroff soft || true
  }

  attach(){
    info "Attaching ISO files" 0
    state="$(vboxmanage showvminfo $VM | grep 'State:')"
    if [[ $state =~ "running" ]]; then
      stopVM
      info "Stopping VM before attach the media" 0
    fi

    vboxmanage storageattach "$VM" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "$DST_CLOVER.iso"
    vboxmanage storageattach "$VM" --storagectl "SATA Controller" --port 2 --device 0 --type dvddrive --medium "$DST_ISO"
  }

  detach(){
    info "Detaching ISO files" 0
    state="$(vboxmanage showvminfo $VM | grep 'State:')"
    if [[ $state =~ "running" ]]; then
      stopVM
      info "Stopping VM before detach the medias" 0
    fi

    vboxmanage storageattach "$VM" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium none 
    vboxmanage storageattach "$VM" --storagectl "SATA Controller" --port 2 --device 0 --type dvddrive --medium none
  }

  # This step runs inmediatly after the vm creation 
  prepareOS(){
    # Attach the installation media
    attach

    # Run the VM
    runVM

    # While the VM installer is prepared, check the status of the VM until it shutdowns.
    echo "Prepare the installation. DO NOT end this script execution, it's waiting for the guest to be prepared and will end automatically." >&4
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

    vboxmanage snapshot $VM take "${name}_${NOW}" --description "$SNAPSHOT_DESCRIPTION"
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
      error "Look at $FILE_LOG for details (or use Console.app). Press enter in the terminal when done..."
      read -r
    fi
  }

  main() {
    while [ "$#" -ne 0 ]; do
      ARG="$1"
      shift # get rid of $1, we saved in ARG already
      case "$ARG" in
        check) runChecks ;;
        clean) runClean ;;
        stash) vboxmanage unregistervm --delete "$VM" || true ;;
        info) echo "$(vboxmanage showvminfo $VM)" >&4 || true ;;
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
  [[ ${BASH_SOURCE[0]} == "${0}" ]] && trap 'cleanup "${?}" "${LINENO}" "${BASH_LINENO}" "${BASH_COMMAND}" $(printf "::%s" ${FUNCNAME[@]:-})' EXIT && main "${@:-}"
  ###############################################################################
