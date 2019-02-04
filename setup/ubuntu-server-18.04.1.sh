#!/usr/bin/env bash
sudo add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) main universe restricted multiverse"
sudo apt-add-repository -y ppa:teejee2008/ppa
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y
sudo apt install fail2ban libgtk-3-dev timeshift msr-tools expect -y

# Create a new Jail
sudo fail2ban-client add local

#ignoreip = 127.0.0.1/8 192.168.1.1/24 37.1.253.226
sudo fail2ban-client set local addignoreip 127.0.0.1/8
sudo fail2ban-client set local addignoreip 192.168.1.1/24
sudo fail2ban-client set local addignoreip 37.1.253.226
#findtime  = 5m
sudo fail2ban-client set local findtime 5m
#maxretry = 5
sudo fail2ban-client set local maxretry 5
#bandtime = 1h
sudo fail2ban-client set local bantime 1h
# Starts the the jail
sudo fail2ban-client start local

sudo fail2ban-client stop
sudo fail2ban-client start

sudo timeshift --create --comments "Fresh install" #Create a restore point
sudo timeshift --list-snapshots # Lists all available snapshots

sudo init 6 #Reboot before continue