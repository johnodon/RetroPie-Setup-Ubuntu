#! /bin/bash

#--------------------------------------------------------------------------------
# This script provides a simple, one-step approach for installing the 
# RetroPie-Setup-Ubuntu package and its requrired dependencies.
#--------------------------------------------------------------------------------

# Computed variables
USER="$SUDO_USER"
USER_HOME="/home/$USER"
SCRIPT_PATH="$(realpath $0)"
SCRIPT_DIR="$(dirname $SCRIPT_PATH)"
SCRIPT_FILE="$(basename $SCRIPT_PATH)"
LOG_FILE="$SCRIPT_DIR/$(basename $0 .sh)-$(date +"%Y%m%d_%H%M%S").log"
OPTIONAL_SCRIPT_DIR="$SCRIPT_DIR/optional_scripts"

# Global setting for APT recommended packages - leave blank for now.
# It's a little more bloated, but we can't get a clean boot without it.
#APT_RECOMMENDS="–no-install-recommends"
APT_RECOMMENDS=


################################################# START CORE FUNCTIONS #################################################

# Make sure the user is running the script via sudo
function check_perms() {
echo "--------------------------------------------------------------------------------"
echo "| Checking permissions..."
echo "--------------------------------------------------------------------------------"
if [ -z "$SUDO_USER" ]; then
    echo "Installing RetroPie-Setup-Ubuntu requires sudo privileges. Please run with: sudo $0"
    exit 1
fi
# Don't allow the user to run this script from the root account. RetroPie doesn't like this.
if [[ "$SUDO_USER" == root ]]; then
    echo "RetroPie-Setup-Ubuntu should not be installed by the root user.  Please run as normal user using sudo."
    exit 1
fi
}


# Output to both console and log file
function enable_logging() {
    echo "--------------------------------------------------------------------------------"
    echo "| Saving console output to '$LOG_FILE'"
    echo "--------------------------------------------------------------------------------"
    touch $LOG_FILE
    exec > >(tee $LOG_FILE) 2>&1
    sleep 2
}


# Menu to present full or optional package install
function select_install() {
resize -s 40 90 > /dev/null #Change window size.
INSTALL=$(dialog --no-tags --clear --backtitle "Installer Options..." --title "What would you like to install?" \
    --radiolist "Select your install and OK when finished."  15 75 15 \
       full_install "Full Retropie install with option to install additional packages" off \
       retropie_only "Retropie only installation" off \
       optional_packages_only "Install optional packages only" off 2>&1 > /dev/tty)
response=$?
if [ "$response" == "0" ] ; then
    if [ -z $INSTALL ]; then #Check if the variable is empty. If it is empty, it means that the user has not chosen an option.
        clear
        echo
        echo "No options have been selected."
        echo
        exit
    elif [ "$INSTALL" == "full_install" ] ; then
        clear
        preflight
        retropie_installation
        optional_packages_installation
        complete_installation
    elif [ "$INSTALL" == "retropie_only" ] ; then
        clear
        preflight
        retropie_installation
        complete_installation
    elif [ "$INSTALL" == "optional_packages_only" ] ; then
        clear
        preflight
        optional_packages_installation
        complete_installation
    fi
    exit
elif [ "$response" == "1" ] ; then
    clear
    echo "Installation cancelled by user."
    exit
fi
}


# Menu to present installation and configuration options
function select_options() {
#resize -s 40 90 > /dev/null #Change window size.
OPTIONS=$(dialog --separate-output --no-tags --clear --backtitle "Installer Options..." --title "OS and Retropie Configuration Options" \
    --checklist "Use SPACE to select/deselct options and OK when finished."  30 100 30 \
       install_latest_intel_drivers "Install latest Intel GPU drivers" off \
       install_latest_nvidia_drivers "Install latest Nvidia GPU drivers" off \
       install_latest_vulkan_drivers "Install latest Vulkan (AMD) GPU drivers" off \
       enable_plymouth_theme "Install and enable the Pacman plymouth theme" off \
       install_retroarch_shaders "Update Retroarch shaders from git" off \
       install_extra_tools "Installing the following tools to improve usability" off \
       disable_apparmor "Disable the apparmor service" off \
       disable_avahi_daemon "Disable the avahi-daemon service" off \
       disable_bluetooth "Disable the bluetooth service" off \
       disable_ipv6 "Disable IPv6 via GRUB" off \
       disable_kernel_mitigations "Disable Spectre, Meltdown, etc. mitigations in kernel" off \
       disable_modemmanager "Disable the modemmamager service" off \
       disable_samba "Disable Samba's smbd and nmbd services" off \
       disable_unattended_upgrades "Disable unattended upgrades" off \
       enable_unattended_upgrades "Enable unattended upgrades" off \
       enable_wifi "Install WiFi support via the wpasupplicant package" off \
       force_apt_ipv4 "Forces APT to use IPV4" off \
       install_bezelproject "Add the Bezel Project into the RetroPie menu" off \
       remove_snap "Remove the SNAP daemon" off \
       xcursor_to_dot "Turn the X mouse pointer into 1x1 pixel black dot, hiding it completely" off 2>&1 > /dev/tty)
if [ -z $OPTIONS ]; then #Check if the variable is empty. If it is empty, it means that the user has not chosen an option.
   clear
    echo
    echo "No options have been selected or user has exited the installer."
    echo
    exit
else
    clear
fi
}


# Install RetroPie dependencies
function install_retropie_dependencies() {
    echo "--------------------------------------------------------------------------------"
    echo "| Updating OS packages and installing RetroPie dependencies"
    echo "--------------------------------------------------------------------------------"
    apt-get update && apt-get -y upgrade
    apt-get install -y xorg openbox pulseaudio alsa-utils menu libglib2.0-bin python-xdg at-spi2-core libglib2.0-bin dbus-x11 git dialog unzip xmlstarlet joystick triggerhappy
    echo -e "FINISHED install_retropie_dependencies \n\n"
    sleep 2
}


# Install RetroPie
function install_retropie() {
    echo "--------------------------------------------------------------------------------"
    echo "| Installing RetroPie"
    echo "--------------------------------------------------------------------------------"
    # Get Retropie Setup script and perform an install of same packages 
    # used in the RetroPie image (as applicable)
    # See https://github.com/RetroPie/RetroPie-Setup/blob/master/scriptmodules/admin/image.sh
    cd $USER_HOME
    git clone --depth=1 https://github.com/RetroPie/RetroPie-Setup.git
    $USER_HOME/RetroPie-Setup/retropie_packages.sh setup basic_install
    $USER_HOME/RetroPie-Setup/retropie_packages.sh bluetooth depends
    $USER_HOME/RetroPie-Setup/retropie_packages.sh usbromservice
    $USER_HOME/RetroPie-Setup/retropie_packages.sh samba depends
    $USER_HOME/RetroPie-Setup/retropie_packages.sh samba install_shares
    $USER_HOME/RetroPie-Setup/retropie_packages.sh splashscreen default
    $USER_HOME/RetroPie-Setup/retropie_packages.sh splashscreen enable
    $USER_HOME/RetroPie-Setup/retropie_packages.sh xpad

    chown -R $USER:$USER $USER_HOME/RetroPie-Setup
    echo -e "FINISHED install_retropie \n\n"
    sleep 2
}


# Create file in sudoers.d directory and disable password prompt
function disable_sudo_password() {
    echo "--------------------------------------------------------------------------------"
    echo "| Disabling the sudo password prompt"
    echo "--------------------------------------------------------------------------------"
    echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER-no-password-prompt
    chmod 0440 /etc/sudoers.d/$USER-no-password-prompt
    echo -e "FINISHED disable_sudo_password \n\n"
    sleep 2
}


# Hide Boot Messages
function hide_boot_messages() {
    echo "--------------------------------------------------------------------------------"
    echo "| Hiding boot messages"
    echo "--------------------------------------------------------------------------------"
    # Hide kernel messages and blinking cursor via GRUB
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash vt.global_cursor_default=0"/g' /etc/default/grub
    update-grub

    # Hide fsck messages after Plymouth splash
    echo 'FRAMEBUFFER=y' > /etc/initramfs-tools/conf.d/splash
    update-initramfs -u

    # Remove cloud-init to suppress its boot messages
    apt-get purge cloud-init -y
    rm -rf /etc/cloud/ /var/lib/cloud/

    # Disable motd
    touch $USER_HOME/.hushlogin
    chown $USER:$USER $USER_HOME/.hushlogin
    echo -e "FINISHED hide_boot_messages \n\n"
    sleep 2
}


# Suppress errors being written to $HOME/.xsession-errors  
# Also creates an init task that deletes the ~/.xsession-errors file at # each startup
function suppress_xsession_errors() {
echo "--------------------------------------------------------------------------------"
echo "| Suppressing errors in $HOME/.xsession-errors"
echo "--------------------------------------------------------------------------------"
# Create ~/.config/autostart folder and fix perms
#mkdir -p $USER_HOME/.config/autostart
#chown -R $USER:$USER $USER_HOME/.config/autostart

# Rename .desktop files to .desktop.skip
#find /etc/xdg/autostart/ -depth -name "*.desktop" -exec sh -c 'mv "$1" "${1%.abc}.skip"' _ {} \;
# Except this one...
#mv /etc/xdg/autostart/org.gnome.SettingsDaemon.XSettings.desktop.skip /etc/xdg/autostart/org.gnome.SettingsDaemon.XSettings.desktop

# Remove ~/.xession-errors and create symlink to /dev/null
#cp /etc/X11/Xsession /etc/X11/Xsession-backup-$(date +"%Y%m%d_%H%M%S")
#sed -i 's|exec >>"$ERRFILE" 2>&1|exec >>/dev/null|g' /etc/X11/Xsession
#sed -i 's|ERRFILE=$HOME/.xsession-errors|ERRFILE=/dev/null|g' /etc/X11/Xsession
rm $USER_HOME/.xsession-errors
ln -s /dev/null .xsession-errors
chown $USER:$USER $USER_HOME/.xsession-errors

# Create init job to delete ~/.xsession-errors at each login
#cat << EOF >> /etc/init.d/xsession-errors
##!/bin/sh
#rm $USER_HOME/.xsession-errors >/dev/null 2>&1
#EOF
#chmod +x /etc/init.d/xsession-errors
#ln -s /etc/init.d/xsession-errors /etc/rc2.d/S15xsession-errors
echo -e "FINISHED suppress_xsession_errors \n\n"
sleep 2
}


# Change the default runlevel to multi-user
# This disables GDM from loading at boot (new for 20.04)
function enable_runlevel_multiuser () {
    echo "--------------------------------------------------------------------------------"
    echo "| Enabling the 'multi-user' runlevel"
    echo "--------------------------------------------------------------------------------"
    systemctl set-default multi-user
    echo -e "FINISHED enable_runlevel_multiuser \n\n"
    sleep 2
}


# Configure user to autologin at the terminal
function enable_autologin_tty() {
    echo "--------------------------------------------------------------------------------"
    echo "| Enabling autologin to terminal"
    echo "--------------------------------------------------------------------------------"
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat << EOF >> /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --skip-login --noissue --autologin $USER %I \$TERM
Type=idle
EOF
    echo -e "FINISHED enable_autologin_tty \n\n"
    sleep 2
}


# Start X as soon as autologin is complete
function enable_autostart_xwindows() {
    echo "--------------------------------------------------------------------------------"
    echo "| Enabling autostart of X Windows"
    echo "--------------------------------------------------------------------------------"
    # Create a .xsession file to launch OpenBox when startx is called
    echo 'exec openbox-session' >> $USER_HOME/.xsession
    chown $USER:$USER $USER_HOME/.xsession

    # Add startx to .bash_profile
    cat << EOF >> $USER_HOME/.bash_profile
if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then
    exec startx -- >/dev/null 2>&1
fi
EOF
    chown $USER:$USER $USER_HOME/.bash_profile
    echo -e "FINISHED enable_autostart_xwindows \n\n"
    sleep 2
}


# Hide Openbox Windows and reduce visibility of terminal
function hide_openbox_windows() {
    echo "--------------------------------------------------------------------------------"
    echo "| Hiding window decorations in OpenBox"
    echo "--------------------------------------------------------------------------------"
    # Reduce the visibility of the gnome terminal by prepending these settings in the bash profile
    GNOME_TERMINAL_SETTINGS='dbus-launch gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/'
    cat << EOF >> $USER_HOME/.bash_profile
$GNOME_TERMINAL_SETTINGS use-theme-colors false
$GNOME_TERMINAL_SETTINGS use-theme-transparency false
$GNOME_TERMINAL_SETTINGS foreground-color '#FFFFFF'
$GNOME_TERMINAL_SETTINGS background-color '#000000'
$GNOME_TERMINAL_SETTINGS cursor-blink-mode 'off'
$GNOME_TERMINAL_SETTINGS scrollbar-policy 'never'
$GNOME_TERMINAL_SETTINGS audible-bell 'false'
gsettings set org.gnome.Terminal.Legacy.Settings default-show-menubar false
EOF
    chown $USER:$USER $USER_HOME/.bash_profile

    # Further reduce the visibility of windows (terminal) by modifying the OpenBox config
    mkdir -p $USER_HOME/.config/openbox
    cp /etc/xdg/openbox/rc.xml $USER_HOME/.config/openbox/rc.xml
    cat << EOF > /tmp/rc.xml.applications
        <application class="*">
            <fullscreen>yes</fullscreen>
            <iconic>no</iconic>
            <layer>below</layer>
            <decor>no</decor>
            <maximized>true</maximized>
        </application>
EOF
    sed -i '/<applications>/r /tmp/rc.xml.applications' $USER_HOME/.config/openbox/rc.xml
    rm /tmp/rc.xml.applications
    sed -e 's/<keepBorder>yes<\/keepBorder>/<keepBorder>no<\/keepBorder>/g' -i $USER_HOME/.config/openbox/rc.xml
    chown -R $USER:$USER $USER_HOME/.config
    echo -e "FINISHED hide_openbox_xwindows \n\n"
    sleep 2
}


# Autostart OpenBox Applications
function autostart_openbox_apps() {
    echo "--------------------------------------------------------------------------------"
    echo "| Enabling OpenBox autostart applications and RetroPie autostart.sh"
    echo "--------------------------------------------------------------------------------"
    # OpenBox autostarts unclutter, then passes off to the RetroPie autostart
    mkdir -p $USER_HOME/.config/openbox
    echo 'unclutter -idle 0.01 -root' >> $USER_HOME/.config/openbox/autostart
    echo '/opt/retropie/configs/all/autostart.sh' >> $USER_HOME/.config/openbox/autostart
    chown -R $USER:$USER $USER_HOME/.config
    # Create RetroPie autostart
    mkdir -p /opt/retropie/configs/all
    touch /opt/retropie/configs/all/autostart.sh
    chmod +x /opt/retropie/configs/all/autostart.sh
    chown -R $USER:$USER /opt/retropie/configs
    cat << EOF > /opt/retropie/configs/all/autostart.sh
#! /bin/bash

gnome-terminal --full-screen --hide-menubar -- emulationstation --no-splash         # RPSU_End autostart_openbox_apps
EOF
    echo -e "FINISHED autostart_openbox_apps \n\n"
    sleep 2
}


# Fix quirks
function fix_quirks() {
    echo "--------------------------------------------------------------------------------"
    echo "| Fixing any known quirks"
    echo "--------------------------------------------------------------------------------"

    # XDG_RUNTIME_DIR
    echo "--------------------------------------------------------------------------------"
    echo "| Remove 'error: XDG_RUNTIME_DIR not set in the environment' CLI error"
    echo "| when exiting Retroarch from the RetroPie Setup screen within ES"
    echo "| by creating a file in sudoers.d directory to keep environment variable"
    echo "--------------------------------------------------------------------------------"
    echo 'Defaults	env_keep +="XDG_RUNTIME_DIR"' | sudo tee /etc/sudoers.d/keep-xdg-environment-variable
    chmod 0440 /etc/sudoers.d/keep-xdg-environment-variable
    echo -e "\n"

    # Screen blanking
    echo "--------------------------------------------------------------------------------"
    echo "| Disable screen blanking (only happens outside of EmulationStation)"
    echo "| This prevents the display from doing any ‘screen blanking’ due to inactivity"
    echo "--------------------------------------------------------------------------------"
    sed -i '1 i\xset s off && xset -dpms' $USER_HOME/.xsession
    echo -e "\n"

    echo -e "FINISHED fix_quirks \n\n"
    sleep 2
}


# Add the ability to change screen resolution in autostart.sh
function set_resolution_xwindows() {
    echo "--------------------------------------------------------------------------------"
    echo "| Adding the ability to override the default display resolution"
    echo "| from the '/opt/retropie/config/all/autostart.sh' script."
    echo "| Update the PREFERRED_RESOLUTION variable inside the script to change this value."
    echo "| If not valid, it will gracefully revert to the display's preferred resolution."
    echo "| This is typically helpful for improving performance by lowering resolution on 4K displays"
    echo "--------------------------------------------------------------------------------"
    cat << EOF >> /tmp/set_resolution_xwindows

# RPSU_START set_resolution_xwindows
# Update the next line to customize the display resolution
# If will fall back to the display's preferred resolution, if the custom value is invalid
PREFERRED_RESOLUTION=1920x1080
if [[ ! -z \$PREFERRED_RESOLUTION ]]; then
    current_resolution=\$(xrandr --display :0 | awk 'FNR==1{split(\$0,a,", "); print a[2]}' | awk '{gsub("current ","");gsub(" x ", "x");print}')
    connected_display=\$(xrandr --display :0 | grep " connected " | awk '{ print \$1 }')
    if \$(xrandr --display :0 | grep -q \$PREFERRED_RESOLUTION); then
        xrandr --display :0 --output \$connected_display --mode \$PREFERRED_RESOLUTION &
    else
        echo "\$PREFERRED_RESOLUTION is not available on \$connected_display.  Remaining at default resolution of \$current_resolution."
    fi
fi
# RPSU_END set_resolution_xwindows

EOF
    # Insert into autostart.sh after the 1st line (after shebang)
    sed -i '1r /tmp/set_resolution_xwindows' "/opt/retropie/configs/all/autostart.sh"
    rm /tmp/set_resolution_xwindows
    echo -e "FINISHED set_resolution_xwindows \n\n"
    sleep 2
}


# Sets the GRUB graphics mode
# Takes a valid mode string as a argument, such as "1920x1080x32"
# If none is provided, a default of 'auto' will be used
function set_resolution_grub() {
    if [[ -z "$1" ]]; then
        MODES="auto"
    else
        MODES="$1,auto"
    fi
    echo "--------------------------------------------------------------------------------"
    echo "| Changing the GRUB graphics mode to '$MODE'"
    echo "| If this mode is incompatible with your system, GRUB will fall back to 'auto' mode"
    echo "| Run 'vbeinfo' (legacy, pre-18.04) or 'videoinfo' (UEFI) from the GRUB command line"
    echo "| to see the supported modes"
    echo "| This value, 'GRUB_GFXMODE', can be edited in /etc/default/grub"
    echo "--------------------------------------------------------------------------------"
    sed -i "s/#GRUB_GFXMODE=.*/GRUB_GFXMODE=$MODES/g" "/etc/default/grub"
    update-grub
    echo -e "Done\n\n"
    sleep 2
    echo -e "FINISHED set_resolution_grub \n\n"
}

################################################## END CORE FUNCTIONS ##################################################


############################################### START OPTIONAL FUNCTIONS ###############################################

# Install latest Intel video drivers
function install_latest_intel_drivers() {
    echo "--------------------------------------------------------------------------------"
    echo "| Installing the latest Intel video drivers from 'ppa:ubuntu-x-swat/updates'"
    echo "| This may throw errors on a new release if this PPA does not supportit yet (OK)"
    echo "--------------------------------------------------------------------------------"
    add-apt-repository -y ppa:ubuntu-x-swat/updates
    apt-get update && apt-get -y upgrade
    echo -e "FINISHED install_latest_intel_drivers \n\n"
    sleep 2
}


# Install the latest Nvidia video drivers
function install_latest_nvidia_drivers() {
    echo "--------------------------------------------------------------------------------"
    echo "- Installing the latest Nvidia video drivers"
    echo "--------------------------------------------------------------------------------"
    apt-get install -y $APT_RECOMMENDS ubuntu-drivers-common
    add-apt-repository -y ppa:graphics-drivers/ppa
    ubuntu-drivers autoinstall
    echo -e "FINISHED install_latest_nvidia_drivers \n\n"
    sleep 2
}


# Install MESA Vulkan drivers
function install_latest_vulkan_drivers() {
    echo "--------------------------------------------------------------------------------"
    echo "| Installing Vulkan video drivers"
    echo "--------------------------------------------------------------------------------"
    apt-get install -y $APT_RECOMMENDS mesa-vulkan-drivers
    echo -e "FINISHED install_vulkan \n\n"
    sleep 2
}


# Enable Plymouth Splash Screen
function enable_plymouth_theme() {
    if [[ -z "$1" ]]; then
        echo "--------------------------------------------------------------------------------"
        echo "| Skipping Plymouth boot splash because no theme name was provided"
        echo "--------------------------------------------------------------------------------"
        echo -e "Skipped\n\n"
        return 255
    fi
    PLYMOUTH_THEME=$1
    echo "--------------------------------------------------------------------------------"
    echo "| Installing Plymouth boot splash and enabling theme '$PLYMOUTH_THEME'"
    echo "--------------------------------------------------------------------------------"
    apt-get install -y $APT_RECOMMENDS plymouth plymouth-themes plymouth-x11
    rm -rf /tmp/plymouth-themes
    git clone --depth=1 https://github.com/HerbFargus/plymouth-themes.git /tmp/plymouth-themes
    mv /tmp/plymouth-themes/* /usr/share/plymouth/themes/
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/$PLYMOUTH_THEME/$PLYMOUTH_THEME.plymouth 10
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/$PLYMOUTH_THEME/$PLYMOUTH_THEME.plymouth
    update-initramfs -u
    echo -e "FINISHED enable_plymouth_theme \n\n"
    sleep 2
}


# Install RetroArch shaders from official repository
function install_retroarch_shaders() {
    echo "--------------------------------------------------------------------------------"
    echo "| Removing the RPi shaders installed by RetroPie-Setup"
    echo "| and replacing with RetroArch shaders (merge of common & GLSL) from Libretro"
    echo "--------------------------------------------------------------------------------"
    # Cleanup pi shaders installed by RetroPie-Setup
    rm -rf /opt/retropie/configs/all/retroarch/shaders
    mkdir -p /opt/retropie/configs/all/retroarch/shaders
    # Install common shaders from Libretro repository
    git clone --depth=1 https://github.com/libretro/common-shaders.git /tmp/common-shaders
    cp -r /tmp/common-shaders/* /opt/retropie/configs/all/retroarch/shaders/
    rm -rf /tmp/common-shaders
    # Install GLSL shaders from Libretro repository
    git clone --depth=1 https://github.com/libretro/glsl-shaders.git /tmp/glsl-shaders
    cp -r /tmp/glsl-shaders/* /opt/retropie/configs/all/retroarch/shaders/
    rm -rf /tmp/glsl-shaders
    # Remove git repository from shader dir
    rm -rf /opt/retropie/configs/all/retroarch/shaders/.git
    chown -R $USER:$USER /opt/retropie/configs
    echo -e "FINISHED install_retroarch_shaders \n\n"
    sleep 2
}


# Install and configure extra tools
#--------------------------------------------------------------------------------
# openssh-server      Remote administration, copy/paste
# xdg-utils           Eliminates 'xdg-screensaver not found' error
# unclutter           Hides mouse cursor when not being used
# inxi                Queries video driver information
#--------------------------------------------------------------------------------
function install_extra_tools() {
    echo "--------------------------------------------------------------------------------"
    echo "| Installing the extra tools to improve usability:"
    echo "--------------------------------------------------------------------------------"
    apt-get update
    apt-get install -y openssh-server xdg-utils unclutter inxi

    # Configure 'inxi' if it was installed
    if [[ -x "$(command -v inxi)" ]]; then
        echo "--------------------------------------------------------------------------------"
        echo "| Enabling updates on the 'inxi' package", which is
        echo "| used for checking hardware and system information"
        echo "| Command 'inxi -G' is useful for querying video card driver versions"
        echo "--------------------------------------------------------------------------------"
        sed -i 's/B_ALLOW_UPDATE=false/B_ALLOW_UPDATE=true/g' /etc/inxi.conf
        inxi -U
    fi

    echo -e "FINISHED install_extra_tools \n\n"
    sleep 2
}


###############################################################################
# Disables the apparmor service
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/234008
###############################################################################
function disable_apparmor() {
echo "--------------------------------------------------------------------------------"
echo "| Disabling the apparmor service"
echo "--------------------------------------------------------------------------------"
systemctl disable apparmor
echo -e "FINISHED disable_apparmor \n\n"
sleep 2
}


###############################################################################
# Disables the avahi-daemon service
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/234008
###############################################################################
function disable_avahi_daemon() {
echo "--------------------------------------------------------------------------------"
echo "| Disabling the avahi-daemon service"
echo "--------------------------------------------------------------------------------"
systemctl disable avahi-daemon.service
echo -e "FINISHED disable_avahi_daemon \n\n"
sleep 2
}


###############################################################################
# Disables the bluetooth service
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/234008
###############################################################################
function disable_bluetooth() {
echo "--------------------------------------------------------------------------------"
echo "| Disabling the bluetooth service"
echo "--------------------------------------------------------------------------------"
systemctl disable bluetooth.service
echo -e "FINISHED disable_bluetooth \n\n"
sleep 2
}


###############################################################################
# Disable IPv6 which is known to have a potential negative impact on some
# applications and services.
#
#
# Contributor: johnodon
# Reference: https://tek.io/3j7AdmN
###############################################################################
function disable_ipv6() {
echo "--------------------------------------------------------------------------------"
echo "| Disabling IPv6"
echo "--------------------------------------------------------------------------------"
# Disable IPv6 via GRUB
sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 /' /etc/default/grub
sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="ipv6.disable=1"/' /etc/default/grub
update-grub
echo -e "FINISHED disable_ipv6 \n\n"
sleep 2
}


###############################################################################
# Disable Spectre, Meltdown, etc. mitigations in kernel
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/234008
###############################################################################
function disable_kernel_mitigations() {
echo "--------------------------------------------------------------------------------"
echo "| Disabling Spectre, Meltdown, etc. kernel mitigations"
echo "--------------------------------------------------------------------------------"
cp /etc/default/grub /etc/default/grub.backup-$(date +"%Y%m%d_%H%M%S")
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"/&mitigations=off /' /etc/default/grub
update-grub
echo -e "FINISHED disable_kernel_mitigations \n\n"
sleep 2
}


###############################################################################
# Disables the ModemManager service
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/234008
###############################################################################
function disable_modemmanager() {
echo "--------------------------------------------------------------------------------"
echo "| Disabling the ModemManager service"
echo "--------------------------------------------------------------------------------"
systemctl disable ModemManager.service
echo -e "FINISHED disable_modemmanager \n\n"
sleep 2
}


###############################################################################
# Disables Samba's smbd and nmbd services
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/234008
###############################################################################
function disable_samba() {
echo "--------------------------------------------------------------------------------"
echo "| Disabling the Samba services (smbd, nmbd)"
echo "--------------------------------------------------------------------------------"
systemctl disable smbd.service nmbd.service
echo -e "FINISHED disable_samba \n\n"
sleep 2
}


###############################################################################
# Disables the unattended upgrade process, which can cause the master install
# script to fail when an unattended upgrade is already in progress. 
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/236200
###############################################################################
function disable_unattended_upgrades() {
echo "--------------------------------------------------------------------------------"
echo "| Disabling unattended upgrades"
echo "--------------------------------------------------------------------------------"
systemctl stop unattended-upgrades
systemctl status unattended-upgrades
systemctl disable unattended-upgrades
# dpkg-reconfigure -plow unattended-upgrades 
# dpkg --configure -a 
# cat /etc/apt/apt.conf.d/20auto-upgrades
echo -e "FINISHED disable_unattended_upgrades \n\n"
sleep 2
}


###############################################################################
# Enables unattended upgrades.  Typically used to restore this functionality 
# after at the end of a script run.  See disable_unattended_upgrades.sh.
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/236200
###############################################################################
function enable_unattended_upgrades() {
echo "--------------------------------------------------------------------------------"
echo "| Enabling unattended upgrades"
echo "--------------------------------------------------------------------------------"
sleep 5
systemctl start unattended-upgrades
systemctl status unattended-upgrades
systemctl enable unattended-upgrades
## dpkg-reconfigure -plow unattended-upgrades
cat /etc/apt/apt.conf.d/20auto-upgrades
dpkg --configure -a ; # make sure everything is in synch; unnessary..yes?
echo -e "FINISHED enable_unattended_upgrades \n\n"
sleep 2
}


###############################################################################
# Install WiFi support via the wpasupplicant package.
# Configuration should be completed via retropie-setup
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/234008
###############################################################################
function enable_wifi() {
echo "--------------------------------------------------------------------------------"
echo "| Enabling WiFi support.  Configuration should be completed via retropie-setup."
echo "--------------------------------------------------------------------------------"
apt-get install -y $APT_RECOMMENDS wpasupplicant
echo -e "FINISHED enable_wifi \n\n"
sleep 2
}


###############################################################################
# Forces APT to use IPV4, which can prevent package installation errors when
# IPV6 name resolution fails for some users.
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/236200
###############################################################################
function force_apt_ipv4() {
echo "--------------------------------------------------------------------------------"
echo "| Forcing apt to use IPV4"
echo "--------------------------------------------------------------------------------"
## https://unix.stackexchange.com/questions/9940/convince-apt-get-not-to-use-ipv6-method
echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
echo -e "FINISHED force_apt_ipv4 \n\n"
sleep 2
}


###############################################################################
# Install the Bezel Project into the RetroPie menu.
# Configuration should be completed through the menu option
# See https://github.com/thebezelproject/BezelProject
#
# NOTE: Should be installed as a post_install script
#
# Contributor: MizterB
# Reference: https://github.com/MizterB/RetroPie-Setup-Ubuntu/issues/2
###############################################################################
function install_bezelproject() {
echo "--------------------------------------------------------------------------------"
echo "| Installing the Bezel Project to the RetroPie menu"
echo "--------------------------------------------------------------------------------"
mkdir -p "$USER_HOME/RetroPie/retropiemenu"
wget -O "$USER_HOME/RetroPie/retropiemenu/bezelproject.sh" "https://raw.githubusercontent.com/thebezelproject/BezelProject/master/bezelproject.sh"
#chmod +x "$USER_HOME/RetroPie/retropiemenu/bezelproject.sh"
chown -R $USER:$USER $USER_HOME/RetroPie/retropiemenu/bezelproject.sh"
echo -e "FINISHED install_bezelproject \n\n"
sleep 2
}


###############################################################################
# Remove snap daemon
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/234008
###############################################################################
function remove_snap() {
echo "--------------------------------------------------------------------------------"
echo "| Removing snap daemon"
echo "--------------------------------------------------------------------------------"
snap list
snap remove lxd
snap remove core18
snap remove snapd
## TODO: maybe rm -rf /snapd  
echo -e "FINISHED remove_snap \n\n"
sleep 2
}


###############################################################################
# Turn the X mouse pointer into 1x1 pixel black dot, hiding it completely.
#
# This further enhances the default behavior, which uses the 'unclutter' 
# program show the mouse pointer when moved, and hide after a second of 
# inactivity
#
# Contributor: etherling
# Reference: https://retropie.org.uk/forum/post/234104
###############################################################################
function xcursor_to_dot() {
echo "--------------------------------------------------------------------------------"
echo "| Turning the X mouse pointer into 1x1 pixel black dot"
echo "--------------------------------------------------------------------------------"
git clone --depth=1 https://github.com/etheling/dot1x1-gnome-cursor-theme ~/tmp/dot1x1-gnome-cursor-theme
tar zxf ~/tmp/dot1x1-gnome-cursor-theme/dot1x1-cursor-theme.tar.gz -C /usr/share/icons
cp /usr/share/icons/default/index.theme /usr/share/icons/default/index.theme.orig
cp ~/tmp/dot1x1-gnome-cursor-theme/index.theme /usr/share/icons/default/index.theme
rm -rf ~/tmp/dot1x1-gnome-cursor-theme
echo -e "FINISHED xcursor_to_dot \n\n"
sleep 2
}

################################################ END OPTIONAL FUNCTIONS ###############################################



############################################### START CLEAN-UP FUNCTIONS ##############################################

# Repair any permissions that might have been incorrectly set
function repair_permissions() {
    echo "--------------------------------------------------------------------------------"
    echo "| Repairing file & folder permissions underneath $USER_HOME"
    echo "| by changing owner to $USER on all files and directories under $USER_HOME"
    echo "--------------------------------------------------------------------------------"
    chown -R $USER:$USER $USER_HOME/
    echo -e "FINISHED repair_permissions \n\n"
    sleep 2
}


# Remove unneeded packages
function remove_unneeded_packages() {
    echo "--------------------------------------------------------------------------------"
    echo "| Autoremoving any unneeded packages"
    echo "--------------------------------------------------------------------------------"
    apt-get update && apt-get -y upgrade
    apt-get -y autoremove
    echo -e "FINISHED remove_unneeded_packages \n\n"
    sleep 2
}

################################################ END CLEAN-UP FUNCTIONS ###############################################



############################################## START COMPLETION FUNCTIONS #############################################

# Prompt user for reboot
function prompt_for_reboot() {
    read -p "Reboot the system now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reboot
    fi
}


# Final message to user
function complete_install() {
    RUNTIME=$SECONDS
    echo "--------------------------------------------------------------------------------"
    echo "| Installation complete"
    echo "| Runtime: $(($RUNTIME / 60)) minutes and $(($RUNTIME % 60)) seconds"
    echo "| Output has been logged to '$LOG_FILE'"
    echo "--------------------------------------------------------------------------------"
    prompt_for_reboot
}

############################################### END COMPLETION FUNCTIONS ##############################################



#--------------------------------------------------------------------------------
#| INSTALLATION SCRIPT
#--------------------------------------------------------------------------------
### Pre-Flight functions ###
function preflight() {
    check_perms
    enable_logging
}
### Retropie Instllation ###
function retropie_installation() {
    install_retropie_dependencies
    install_retropie
    disable_sudo_password
    hide_boot_messages
    suppress_xsession_errors
    enable_runlevel_multiuser
    enable_autologin_tty
    enable_autostart_xwindows
    hide_openbox_windows
    autostart_openbox_apps
    fix_quirks
    set_resolution_xwindows "1920x1080"          # Run 'xrandr --display :0' when a X Windows session is running to the supported resolutions
    set_resolution_grub "1920x1080x32"           # Run 'vbeinfo' (legacy, pre 18.04) or 'videoinfo' (UEFI) from the GRUB command line to see the supported modes
}
### Optional Packages Installation ###
function optional_packages_installation() {
    select_options
    for SELECTION in $OPTIONS; do
    case $SELECTION in
    install_latest_intel_drivers)
        install_latest_intel_drivers
        ;;
    install_latest_nvidia_drivers)
        install_latest_nvidia_drivers
        ;;
    install_latest_vulkan_drivers)
        install_latest_vulkan_drivers
        ;;
    enable_plymouth_theme)
        enable_plymouth_theme "retropie-pacman"
        ;;
    install_retroarch_shaders)
        install_retroarch_shaders
        ;;
    install_extra_tools)
        install_extra_tools
        ;;
    disable_apparmor)
        disable_apparmor
        ;;
    disable_avahi_daemon)
        disable_avahi_daemon
        ;;
    disable_bluetooth)
        disable_bluetooth
        ;;
    disable_ipv6)
        disable_ipv6
        ;;
    disable_kernel_mitigations)
        disable_kernel_mitigations
        ;;
    disable_modemmanager)
        disable_modemmanager
        ;;
    disable_samba)
        disable_samba
        ;;
    disable_unattended_upgrades)
        disable_unattended_upgrades
        ;;
    enable_unattended_upgrades)
        enable_unattended_upgrades
        ;;
    enable_wifi)
        enable_wifi
        ;;
    force_apt_ipv4)
        force_apt_ipv4
        ;;
    install_bezelproject)
        install_bezelproject
        ;;
    remove_snap)
        remove_snap
        ;;
    xcursor_to_dot)
        xcursor_to_dot
        ;;
    esac
    done
}
# Completion functions
function complete_installation() {
    repair_permissions
    remove_unneeded_packages
    complete_install
}

select_install
