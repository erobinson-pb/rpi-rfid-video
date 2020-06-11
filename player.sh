#!/bin/bash

#user defined variables
usbmnt=/media/usb #directory where the USB devices are mounted
tmp=/media/tmp #temp directory one - mounted in RAM as per fstab to enhance longevity of the sd card - used to store the ID of the most recently scanned tags
tmp2=/media/tmp2 #temp directory two - as above, mounted in RAM  - for any other temporary operations
home=/home/pi/rpi-rfid-video #where the scripts live
datfile="${home}/datfile" #location of the data file that matches tag IDs to movie files
debug="off" #uncomment this line to enable debug logging to $home/tmplog

function _getmoviename {
        #check the data file for the scanned tag no (passed as a parameter) and lookup corresponding movie file if the record  exists
        movie=""
        _log "_getmoviename is checking data file for tag ${1}"
        readline=$(cat "${datfile}" | grep "${1}")
        if [[ "${readline}" != "" ]]; then
                _log "tag exists in the database: $readline -  checking if the movie file exists"
                #an entry exists, get the corresponding movie file and check if it exists.  If it does return the movie name otherwise return empty string.
                movie=$(cut -d ":" -f 2 <<< "${readline}")
                _log "Movie: ${movie}"
                [ -f "${movie}" ] || movie=""
        else
                _log "unable to find tag ${1} in database"
        fi
}

function _stopall {
        output=$(pgrep -f "fbi")
        if [[ "${output}" != "" ]]; then
                killall fbi &>/dev/null
                clear
        fi
        output=$(pgrep -f "omxplayer")
        if [[ "${output}" != "" ]]; then
                dbuscontrol.sh stop &>/dev/null
                state="idle"
                clear
        fi
}

function _showbanner {
        #Show an informational banner on the screen
        _stopall
        _log "showing banner ${home}/${1}"
        screen -dm fbi -T 1 -noverbose -a "${home}"/"${1}" &>/dev/null &
}

function _startmovie {
        #Play a new movie from the beginning
        _stopall
        state="playing"
        clear
        screen -dm omxplayer "${1}" &>/dev/null &
}

function _pauseresume {
        #Pause or resume a movie
        _log "Running dbuscontrol.sh pause &>/dev/null"
        dbuscontrol.sh pause &>/dev/null
}

function _log {
        #debug log
        if [[ $debug == "on" ]]; then
                echo "${1}">>"${home}"/tmplog
        fi
}

function _getscantimediff {
        lastscantime=$(stat -c %Y "${tmp}"/"${ID}")
        curdate=$(date +%s)
        scandiff=$(expr $curdate - $lastscantime)
}

function _menu {
        _stopall #Stop any movie playing and close any banners
        if [[ $1 == "notag" ]]; then #if the menu was brought up before a tag is scanned, assume the user wants remote support
                selection=$( dialog --stdout --title "Maintenance" --menu "Maintenance options:" 0 0 0 1 "Exit this menu" 2 "Enable remote support" )
                clear
                if [[ $selection == 2 ]]; then
                        echo "You have enabled remote support mode.  In remote support mode, the system will reboot, connect to the WiFi network if an access point is available"
                        echo "and attempt to connect to the support VPN, if configured, to allow remote support to be provided.  You will be able to access the system over SSH."
                        echo "The system will remain in remote support mode until reset."
                        echo "Press any button to enter remote support"
                        read -n 1 -s > /dev/null 2>&1
                        #copy the config files then reboot
                        touch "${home}"/supporton
                        shutdown -r now
                fi
        else
                selection=$( dialog --stdout --title "Maintenance" --menu "Maintenance options:" 0 0 0 1 "Exit this menu" 2 "Link a movie to the last scanned tag" )
                clear
                if [[ $selection == 2 ]]; then
                        _log "Choice is: link a movie to the current tag"
                        #Link a movie to the current tag
                        if [[ "${ID}" != "" ]]; then
                                _log "ID: ${ID} - enumerate devices"
                                #Something has been placed on the scanner and an ID exists
                                #dynamically build the menu based on movie files in /media/usb
                                i=0
                                W=()
                                while read -r line; do
                                        let i=$i+1
                                        W+=($i "${line}")
                                        _log "device line=${line}"
                                done < <( ls -1 "${usbmnt}" )
                                _log "Device count=${i}"
                                if [ i == 0 ]; then
                                        selection=$( dialog --stdout --title "Maintenance" --menu "Unable to find a USB drive.  Please attach one and restart the system." 0 0 0 1 "Exit" )
                                else
                                        _log "menu parameters: Choose the storage device by ID 24 80 17 ${W[@]}"
                                        device=$( dialog --title "Storage device selection" --menu "Choose the storage device by ID" 24 80 17 "${W[@]}" 3>&2 2>&1 1>&3 )
                                        clear
                                        _log "Chosen menu item: ${device}, get device name"
                                        i=0
                                        while read -r line; do
                                                let i=$i+1
                                                if [[ $i == "${device}" ]]; then
                                                        device="${line}"
                                                fi
                                        done < <( ls -1 "${usbmnt}" )
                                        _log "Device name: ${device}"
                                        clear
                                        if [[ "${device}" != "" ]]; then #if a choice was made
                                                _log "Getting list of movies for device ${device}"
                                                i=0
                                                W=()
                                                while read -r line; do
                                                        let i=$i+1
                                                        W+=($i "${line}")
                                                        _log "movie line=${line}"
                                                done < <( ls -1 "${usbmnt}"/"${device}" )
                                                _log "Movie count for device: ${i}"
                                                if [[ $i != "0" ]]; then
                                                        selection=$( dialog --title "Movie selection" --menu "Choose the movie" 24 80 17 "${W[@]}" 3>&2 2>&1 1>&3 )
                                                        i=0
                                                        while read -r line; do
                                                                let i=$i+1
                                                                if [[ $i == "${selection}" ]]; then
                                                                        selection="${line}"
                                                                fi
                                                        done < <( ls -1 "${usbmnt}"/"${device}" )
                                                        clear
                                                        if [[ "${selection}" != "" ]]; then
                                                                _log "Something chosen - update the datafile linking the ID to the movie"
                                                                #Update the datfile
                                                                sed -i "/\b\($ID\)\b/d" "${datfile}" #remove any lines referring to the ID
                                                                echo "${ID}":"${usbmnt}"/"${device}"/"${selection}">>"${datfile}" #add the line back with the new movie name
                                                                ID="" #reset the scanned ID tag so it will recognize the new movie and start playing automatically
                                                        else
                                                                _log "No movie was chosen - quit the menu"
                                                        fi
                                        else
                                                _log "No movies on the device"
                                                if [[ $state == "unrecognized" ]]; then
                                                        _showbanner unidentified.png
                                                elif [[ $state == "idle" ]]; then
                                                        _showbanner ready.png
                                                fi
                                        fi
                                        else
                                                _log "No flash drive was chosen - quit the menu"
                                        fi
                                fi
                        else
                                _log "ID variable is empty - ignore and quit the menu"
                        fi
                else
                        _log "Menu exited without linking a movie to the last scanned tag - state is ${state}"
                        if [[ $state == "unrecognized" ]]; then
                                _showbanner unidentified.png
                        elif [[ $state == "idle" ]]; then
                                _showbanner ready.png
                        fi
                fi
        fi

}

function _vpn {
        echo "VPN Stuff"
}

function _mount {
        [ -d "${usbmnt}" ] || mkdir "${usbmnt}"
        #Look for storage devices other than the default SD Card and mount them at /dev/usb/UUID
        ls -l /dev/disk/by-uuid > "${tmp2}"/usb
        #iterate through devices
        while IFS="" read -r p
        do
                set -- $p
                _log "p = ${p}"
                case $p in
                        *mmcblk* )
                                #ignore SD card
                                _log "Ignore SD card"
                        ;;
                        * )
                                _log "Device: ${9}"
                                #for all other devices
                                if [[ $9 != "" ]]; then
                                        #create a folder under $usbmnt with the device name and mount it there
                                        _log "checking if ${usbmnt}/${9} exists and creating it if not"
                                        [ -d "${usbmnt}"/$9 ] || mkdir "${usbmnt}"/$9
                                        _log "mounting UUID ${9} to ${usbmnt}/${9}"
                                        mount UUID=$9 "${usbmnt}"/$9
                                fi
                                _log "Next device"
                        ;;
                esac
                _log "end case statement"
        done < "${tmp2}"/usb

        #next we remove any left over folders in /media/usb from previous devices no longer present
        _log "removing unused mount folders"
        ls -1 /media/usb > "${tmp2}"/usb2
        #iterate through folders
        while IFS="" read -r p
        do
                _log "iterating through folders - ${p}"
                result=$(cat "${tmp2}"/usb | grep $p)
                if [[ "${result}" == "" ]]; then
                        #device not found to match this folder - this is an old folder, remove
                        _log "no device found - remove ${p}"
                        rm -Rf /media/usb/$p
                fi
        done < "${tmp2}"/usb2
}

#startup - first check if in support mode or normal mode
_log "starting up - check if in support or normal mode"
if [ -f "${home}"/supporton ]; then
        rm "${home}"/supporton
        echo "Support mode is enabled.  You can connect to the device with SSH or connect a keyboard and press Ctrl-C to access the shell directly."
        echo "To exit support mode, reset or reboot the unit."
        wifiadd=$(ifconfig wlan0| grep 'inet ')
        echo "WiFi connection IP Address: ${wifiadd}"
        echo "Attempting VPN connection in 30 seconds"
        sleep 30
        ethadd=$(ifconfig eth0| grep 'inet ')
        echo "Ethernet connection IP address: ${ethadd}"
        echo "Attempting to connect to the support VPN if it is enabled - waiting 30 seconds between tries."
        attempt=1
        connected=""
        while [[ $attempt -lt 4 && $connected == "" ]]; do
                echo Attempt $attempt
                _vpn
                sleep 30
                let attempt=$attempt+1
        done
        if [[ $connected == "true" ]]; then
                ipadd=/sbin/ifconfig tun0| grep 'inet addr:'
                echo "VPN connection IP address: ${ipadd}"
        else
                echo "Unable to connect to the remote support VPN.  Local support is enabled via SSH or directly via on-screen terminal only."
        fi

        exit 0 #exit the script at this point
fi

_log "Normal mode - continuing..."
###################
#Startup

#Normal mode - mount any USB devices at /media/usb
_log "mount devices"
_mount
_log "setting variables"
#display the instructional banner then look for files in the tmp2 folder deposited by scansvc.service
#if there is no token on the scanner, no files will be found
#if there is a tag on the scanner, a file with the tag ID as it's name will be found
key="" #stores the key pressed when a key is pressed on the keyboard
ID="" #stores the tag ID
IDcompare="" #used to check if the ID has changed
state="idle" #the state of the system - idle if idle, unrecognized if an unrecognized tag is placed, playing if a movie is playing, paused if a movie is paused
movie="" #initialize the movie variable
_log "Check if datfile exists and create if not"
[ -f "${datfile}" ] || touch "${datfile}" #create the datfile if it doesn't exist
_log "show ready banner"
_showbanner ready.png #show the ready banner and loop until a tag is read
while [[ "${ID}" == "" ]]; do
        _log "first look for a tag"
        ID=$(ls "${tmp}"/)
        _log "listening for keypress for 2 seconds"
        #briefly listen for a keypress.  If a key is pressed, then bring up the menu
        read -rsn1 -t 2 key > /dev/null 2>&1
        _log "key=${key}"
        if [[ "${key}" != "" ]]; then
                _log "key pressed - Clear screen and bring up the menu without movie options"
                _menu "notag" #start the menu without the option to select a movie since there is nothing on the scanner - remote support only
                key=""
                _showbanner ready.png
        else
                _log "continue without keypress"
        fi
done
_log "tag found"
_log "check if it is current or old"
#found a file - set the starttime variable used to determine if the item on the scanner is still there
_getscantimediff
_log "curdate: ${curdate} lastscantime: ${lastscantime} scandiff: ${scandiff}"
if [[ $scandiff -lt 4 ]]; then #the tag is on the tray and active - see if a movie is associated with it
        _log "running _getmoviename for ${ID} to see if the tag is associated with a movie"
        _getmoviename "${ID}"
        if [[ "${movie}" != "" ]]; then
                _log "movie name is associated with this tag: $movie - start the movie"
                _startmovie "${movie}"
        else
                _log "no movie associated with this tag or the movie file doesn't exist - show unidentified tag set state to unrecognized"
                state="unrecognized"
                _showbanner unidentified.png
        fi
else
        _log "tag is no longer on the tray"
fi


###################
#Main Scan Loop
while true
do
        _log "###"
        _log "begin main scan loop - compare current tag with last known tag to see if it's changed"
        #keep an eye on the scanner for changes - either nothing on the scanner or a change to what's on the scanner
        #We have $ID and scanstart time to see if the movie has been changed or taken off the scanner
        IDcompare=$(ls "${tmp}/")
        if [[ "${IDcompare}" != "${ID}" ]]; then
                _log "ID has changed - new tag or movie - reset ID to current tag and see if the tag is associated with a movie"
                #ID has changed - New tag or movie
                ID="${IDcompare}"
                _getmoviename "${ID}"
                if [[ "${movie}" != "" ]]; then
                        _log "Movie file exists, play it"
                        #movie file exists, play it
                        _startmovie "${movie}"
                else
                        _log "Movie file does not exist, show unidentified tag banner and set state to unrecognized"
                        #movie file doesn't exist - show unrecognized tag banner
                        _showbanner unidentified.png
                        state="unrecognized"
                fi
        else
                _log "tag is the same - check state: ${state}"
                #ID is the same - check last scan time and see if the dvd is on the tray or off
                _getscantimediff
                _log "curdate: ${curdate} lastscantime: ${lastscantime} scandiff: ${scandiff}"
                if [[ $scandiff -gt 4 ]]; then #Tag is the same and off the scanner
                        _log "Tag is no longer on the scanner - check state"
                        #Token hasn't been scanned in the last 3 seconds - nothing is on the scanner
                        if [[ "${state}" == "playing" ]]; then
                                _log "Movie is playing - pause it"
                                #If a movie is playing then pause it
                                state="paused"
                                _pauseresume
                        elif [[ "${state}" == "paused" ]]; then
                                _log "state is paused - leave it as is"
                        else
                                _log "No tag on the scanner and movie not playing - check if current state is idle or unrecognized"
                                #movie not playing and token hasn't been scanned in the last 3 seconds
                                if [[ "${state}" != "idle" ]]; then
                                        _log "No tag on the scanner - set to idle"
                                        state="idle"
                                        _showbanner ready.png
                                else
                                        _log "No tag on the scanner and state is idle - leave it as is"
                                fi
                        fi
                else
                        _log "Tag is the same and on the scanner - check state (${state})"
                        #Tag is the same and on the scanner - check state
                        if [[ "${state}" != "playing" ]]; then #proceed with further checks if not playing
                                _log "Movie is not playing"
                                if [[ "${state}" == "idle" ]]; then
                                        _log "State is idle - get movie name"
                                        _getmoviename "${ID}"
                                        if [[ "${movie}" != "" ]]; then
                                                _log "movie name is associated with this tag: $movie - start the movie"
                                                _startmovie "${movie}"
                                        else
                                                _log "no movie associated with this tag or the movie file doesn't exist - show unidentified tag set state to unrecognized"
                                                state="unrecognized"
                                                _showbanner unidentified.png
                                        fi
                                elif [[ "${state}" == "paused" ]]; then #if paused, then resume
                                        _log "State is paused, resume"
                                        state="playing"
                                        _pauseresume
                                else
                                        _log "state is unrecognized, no change"
                                fi
                        else #playing - check that it's still running, show the fin banner if not
                                if [[ $(pgrep -f "omxplayer") == "" ]]; then #movie has finished
                                        state="fin"
                                        _showbanner fin.png
                                fi
                        fi
                fi
        fi

        _log "listening for keypress for 2 seconds"
        #briefly listen for a keypress.  If a key is pressed, then bring up the menu
        read -rsn1 -t 2 key > /dev/null 2>&1
        if [[ "${key}" != "" ]]; then
                _log "key pressed - stop playing if playing, close banners, clear screen and bring up the menu"
                _menu
        else
                _log "continue without keypress"
        fi

done
