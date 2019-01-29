  #!/usr/bin/env bash
  #
  # DESCRIPTION
  # Run macOS 10.14 Mojave in Virtualbox.
  #
  # CREDITS
  # Source  : https://github.com/AlexanderWillner/runMacOSinVirtualBox
  ###############################################################################
  # Core parameters #############################################################
  AgentLogonPassword=$1

  if [ -z "$AgentLogonPassword" ]; then
    read -s -p "Password for $USER (ENTER to continue, will be requested later!): " AgentLogonPassword
    echo ""
  fi

  readonly PREPARATION_TIMEOUT=1800 # 30 minutes
  readonly VM_SIZE="102400" # 100 Gb
  readonly VM_RES="1366x768"
  readonly VM_RAM="4096" # 4Gb
  readonly VM_VRAM="128"
  readonly VM_CPU="2"

  readonly RDP_PORT="3389"
  readonly SSH_PORT="2222"
  readonly EXT_PACK_LICENSE="56be48f923303c8cababb0bb4c478284b688ed23f16d775d729b89a2e8e5f9eb"

  readonly PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin"
  readonly SCRIPTPATH="$(
    cd "$(dirname "$0")" || exit
    pwd -P
  )"

  # Idenfity platform
  PLATFORM=`uname`

  # Extract ISO name
  name="$(find $SCRIPTPATH -maxdepth 1 -type f -name '*.iso.cdr' -print -quit)"

  if [[ "$name" == "" ]]; then
    echo "ISO files not found, attempting to download them."
    # expect ./copy-isos.exp

    # hostAddress="195.154.60.70"
    # loginUser="cimac"
    # loginPassword="Gre98Sec12"

    # expect -c "set timeout -1; spawn scp -oStrictHostKeyChecking=no $loginUser@$hostAddress:~/installer/*-Clover.iso \"$::env(HOME)/installer\"; expect \"password:\" {send \"$loginPassword\r\"; exp_continue}"
    # expect -c "set timeout -1; spawn scp -oStrictHostKeyChecking=no $loginUser@$hostAddress:~/installer/*.iso.cdr \"$::env(HOME)/installer\"; expect \"password:\" {send \"$loginPassword\r\"; exp_continue}"

    wget --ftp-user=sd-55951 --ftp-password=gm1x0n55951 ftp://dedibackup-dc2.online.net/ci_mojave/* --directory-prefix=installer/ && echo "ISOs files downloaded."
  fi

  name="$(find $SCRIPTPATH -maxdepth 1 -type f -name '*.iso.cdr' -print -quit)"
  name=${name##*/}
  name=${name%.*.*};
  readonly VM="$name"

  readonly DST_DIR="$HOME/VirtualBox VMs/"
  readonly VM_DIR="$DST_DIR$VM"
  readonly DST_CLOVER="$SCRIPTPATH/${VM}-Clover"
  readonly DST_VOL="/Volumes/$VM"
  readonly DST_ISO="$SCRIPTPATH/$VM.iso.cdr"
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
        expectify "sudo apt install msr-tools -y"
      fi

      VT_CHECK="$(sudo modprobe msr && sudo rdmsr 0x3a)"

      echo "Checking virtualization: $VT_CHECK"

      if [ \("$VT_CHECK" = ""\) -o \("$VT_CHECK" = "0"\) ]; then
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
    expectify "wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -"
    expectify "wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -"
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
      vboxmanage createhd --filename "$VM_DIR/$VM.vdi" --variant Standard --size "$VM_SIZE"
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
      *) echo "Possible commands: create, clean, all, check, install, run, prepare, stop, stash" >&4 ;;
      esac
    done
  }
  ###############################################################################

  # Run script ##################################################################
  [[ ${BASH_SOURCE[0]} == "${0}" ]] && trap 'cleanup "${?}" "${LINENO}" "${BASH_LINENO}" "${BASH_COMMAND}" $(printf "::%s" ${FUNCNAME[@]:-})' EXIT && main "${@:-}"
  ###############################################################################