#!/bin/bash

#recommend sudo apt install rpi-eeprom and sudo rpi-eeprom-update -a for Rpi 4
#recommend sudo touch /boot/ssh to enable ssh

cr=$'\n'
function _next {
        let stage=$stage+1
        echo "${cr}---${cr}Stage: ${stage} - ${1}${cr}---${cr}"
}

function yesno {
        #function that asks yes/no question - anything but N is assumed Y - if N is provided, user is asked to confirm if they are sure
        #two parameters are passed - the initial question and the confirmation question if they change their mind after answering N initially.
        read -p "${1} ${cr}" -n 1 -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
                read -p "${cr}Are you sure? ${cr}" -n 1 -r
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                        read -p "${cr}${2} ${cr}" -n 1 -r
                else REPLY=n
                fi
        fi
}

function exit_on_error {
    exit_code=$1
    last_command=${@:2}
    if [ $exit_code -ne 0 ]; then
        >&2 echo "\"${last_command}\" command failed with exit code ${exit_code}."
        exit $exit_code
    fi
}

#check if run as root/sudo
if [[ $(id -u) -ne 0 ]]; then
        echo "Installer must be run as root."
        echo "Try 'sudo $0'"
        exit 1
fi

if [[ $1 == "" ]]; then
        stage=1
else
        stage=$1
        echo Continuing install script at stage $1
fi
#check if the user wants retrogame
yesno "Have you installed the buttons and do you want to use retrogame to manage button presses to keyboard conversion? " "Last chance to confirm - do you want to use retrogame? "
retrogame=${REPLY}
echo ${cr}

if [[ $stage == 1 ]]; then
    echo Create temp folders for the app
    mkdir /media/usb >/dev/null 2>&1
    mkdir /media/tmp >/dev/null 2>&1
    mkdir /media/tmp2 >/dev/null 2>&1
    echo Update /etc/fstab to auto mount temp folders to RAM
        grep "/media/tmp " /etc/fstab >/dev/null
        if [[ $? != 0 ]]; then
                echo /media/tmp does not exist in fstab - add it
                echo "tmpfs /media/tmp tmpfs nodev,nosuid,size=1M 0 0" >> /etc/fstab
        fi
        grep "/media/tmp2" /etc/fstab >/dev/null
        if [[ $? != 0 ]]; then
                echo /media/tmp2 does not exist in fstab - add it
                echo "tmpfs /media/tmp2 tmpfs nodev,nosuid,size=1M 0 0" >> /etc/fstab
        fi
        echo Set GPU memory split to 256 for raspberry pi 4 or 128 for raspberry pi 3 or lower
        cat  /proc/cpuinfo | grep "Pi 4" >/dev/null
        if [[ $? != 0 ]]; then
                echo This is a pi 3 or lower - memory split is 128
                raspi-config nonint do_memory_split 128
        else
                echo This is a pi 4 - memory split is 256
                raspi-config nonint do_memory_split 256
         fi
        echo Enable SPI for the MFRC522 RFID scanner
        raspi-config nonint do_spi 0
        exit_on_error $?
        _next "Perform update / upgrade"
fi

if [[ $stage == 2 ]]; then
        #Perform update / upgrade
        echo ...Running apt-get update and upgrade
        apt-get update -y
        exit_on_error $?
        apt-get upgrade -y
        exit_on_error $?
        echo ...now installing various required apps and scripts - first git
        apt-get install git -y
        exit_on_error $?
        echo ...then python 3 and pip
        apt-get install python3-dev python3-pip -y
        exit_on_error $?
        echo ...now spidev and mfrc522
        pip3 install spidev
        exit_on_error $?
        pip3 install mfrc522
        exit_on_error $?
        echo ...now OMXPlayer
        apt-get install omxplayer -y
        exit_on_error $?
        echo ...and python3-gpiozero
        apt-get install python3-gpiozero -y
        echo ...and screen
        apt-get install screen -y
        exit_on_error $?
        #To do - check if hdmi_force_hotplug=1 and hdmi_drive=2 are enabled in /boot/config.txt
        exit_on_error $?
        echo ...and, fbi
        apt-get install fbi -y
        exit_on_error $?
        echo ...lastly, dialog
        apt-get install dialog -y
        exit_on_error $?
        _next "Downloading application script and assets"
fi

if [[ $stage == 3 ]]; then
	#Downloading application script and assets
    echo Downloading main application script and assets
    rm -Rf rpi-rfid-video >/dev/null
	git clone https://github.com/peg-leg/rpi-rfid-video.git
    exit_on_error $?
    echo Set executable flag on main player script
    chmod +x /home/pi/rpi-rfid-video/player.sh
    exit_on_error $?
    echo ...and set executable flag on dbuscontrol.sh
    chmod +x /home/pi/rpi-rfid-video/dbuscontrol.sh
    exit_on_error $?
    echo move dbuscontrol.sh to /usr/local/bin/
    mv /home/pi/rpi-rfid-video/dbuscontrol.sh /usr/local/bin/dbuscontrol.sh
    exit_on_error $?
    _next "If retrogame is being used for push-buttons, set it up, if not, skip"
fi

if [[ $stage == 4 ]]; then
	if [[ $retrogame = y ]]; then
		#If retrogame is being used for push-buttons:
        echo Copy retrogame executable to /usr/local/bin
		cp rpi-rfid-video/retrogame /usr/local/bin
        exit_on_error $?
        echo Update executable flag for retrogame executable
		chmod 755 /usr/local/bin/retrogame
        exit_on_error $?
        echo Copy retrogame config file to /boot
		cp rpi-rfid-video/retrogame.cfg /boot/retrogame.cfg
        exit_on_error $?
        echo Add /etc/udev/rules.d rule for retrogame
		echo "SUBSYSTEM==\"input\", ATTRS{name}==\"retrogame\", ENV{ID_INPUT_KEYBOARD}=\"1\"" > /etc/udev/rules.d/10-retrogame.rules
        exit_on_error $?
        echo Configure retrogame to start at boot-up
		grep retrogame /etc/rc.local >/dev/null
		if [[ $? -eq 0 ]]; then
			# retrogame already in rc.local, but make sure correct:
			sed -i "s/^.*retrogame.*$/\/usr\/local\/bin\/retrogame \&/g" /etc/rc.local >/dev/null
            exit_on_error $?
		else
			# Insert retrogame into rc.local before final 'exit 0'
			sed -i "s/^exit 0/\/usr\/local\/bin\/retrogame \&\\nexit 0/g" /etc/rc.local >/dev/null
            exit_on_error $?
		fi
	fi
	_next "Update /etc/rc.local with scanner service python script"
fi

if [[ $stage == 5 ]]; then
	echo update /etc/rc.local to auto start scanner service python script
	grep "scansvc.py" /etc/rc.local >/dev/null
	if [[ $? -eq 0 ]]; then
		# scansvc already in rc.local, but make sure correct:
		sed -i "s/^.*scansvc.*$/python3 \/home\/pi\/rpi-rfid-video\/scansvc.py \&/g" /etc/rc.local >/dev/null
        exit_on_error $?
	else
		# Insert scansvc.py into rc.local before final 'exit 0'
		sed -i "s/^exit 0/python3 \/home\/pi\/rpi-rfid-video\/scansvc.py \&\\nexit 0/g" /etc/rc.local >/dev/null
        exit_on_error $?
	fi
	echo update /etc/rc.local with player.sh script
	grep "player.sh" /etc/rc.local >/dev/null
	if [[ $? -eq 0 ]]; then
		# player.sh already in rc.local, but make sure correct:
		sed -i "s/^.*player.*$/openvt -s -w \/home\/pi\/rpi-rfid-video\/player.sh/g" /etc/rc.local >/dev/null
        exit_on_error $?
	else
		# Insert player.sh into rc.local before final 'exit 0'
		sed -i "s/^exit 0/openvt -s -w \/home\/pi\/rpi-rfid-video\/player.sh \\nexit 0/g" /etc/rc.local >/dev/null
        exit_on_error $?
	fi
    echo Update /boot/cmdline.txt for silent boot
    partuuid=$(cat /boot/cmdline.txt | grep -o -P '(?<=PARTUUID=).*' | awk '{print $1}')
    sh -c "echo 'console=serial0,115200 console=tty3 root=PARTUUID=$partuuid rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait vt.global_cursor_default=0 loglevel=3 quiet'>/boot/cmdline.txt"
    exit_on_error $?
    echo Done!
fi
