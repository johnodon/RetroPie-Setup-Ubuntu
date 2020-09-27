#!/bin/bash

resize -s 40 90 > /dev/null #Change window size.
options=$(dialog --no-tags --clear --backtitle "Installer Options..." --title "OS and Retropie Configuration Options" \
    --checklist "Use SPACE to select/deselct options and OK when finished."  30 100 30 \
       install_latest_nvidia_drivers "Install latest Nvidia GPU drivers" off \
       install_latest_intel_drivers "Install latest Intel GPU drivers" off \
       install_vulkan "Install latest Vulkan (AMD) GPU drivers" off \
       install_retroarch_shaders "Update Retroarch shaders from git" off \
       disable_apparmor "Disable the apparmor service" off \
       disable_ipv6 "Disable IPv6 via GRUB" off \
       disable_avahi "Disable the avahi-daemon service" off \
       disable_bluetooth "Disable the bluetooth service" off \
       disable_kernel_mitigations "Disable Spectre, Meltdown, etc. mitigations in kernel" off \
       disable_samba "Disable Samba's smbd and nmbd services" off \
       disable_unattended "Disable unattended upgrades" off \
       enable_wifi "Install WiFi support via the wpasupplicant package" off \
       force_apt_ipv4 "Forces APT to use IPV4" off \
       add_bezelproject "Install the Bezel Project into the RetroPie menu" off \
       remove_snap "Remove the SNAP daemon" off \
       suppress_xsession_errors "Prevent errors from being written to ~/.xsession-errors" off \
       xcursor_to_dot "Turn the X mouse pointer into 1x1 pixel black dot, hiding it completely" off \
       disable_modemmanager "Disable the modemmamager service" off 2>&1 > /dev/tty)
if [ -z $options ]; then #Check if the variable is empty. If it is empty, it means that the user has not chosen an option.
 clear
 echo
 echo "No options have been selected or script was canceled."
 echo
   else
 clear
 echo  "$options"
 echo
fi
exit
