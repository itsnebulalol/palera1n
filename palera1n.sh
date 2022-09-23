#!/usr/bin/env bash

set -e

# Prevent Finder from complaning
if [ "$os" = 'Darwin' ]; then
    defaults write -g ignore-devices -bool true
    defaults write com.apple.AMPDevicesAgent dontAutomaticallySyncIPods -bool true
    killall Finder
fi

# =========
# Variables
# =========
version="1.0.0"
os=$(uname)
dir="$(pwd)/binaries/$os"
if [[ "$@" == *"--debug"* ]]; then
    out=/dev/stdout
else
    out=/dev/null
fi

# =========
# Functions
# =========
step() {
    for i in $(seq "$1" -1 1); do
        printf '\r\e[1;36m%s (%d) ' "$2" "$i"
        sleep 1
    done
    printf '\r\e[0m%s (0)\n' "$2"
}

_wait() {
    if [ "$1" = 'normal' ]; then
        if [ "$os" = 'Darwin' ]; then
            if ! (system_profiler SPUSBDataType 2> /dev/null | grep 'Manufacturer: Apple Inc.' >> /dev/null); then
                echo "[*] Waiting for device in normal mode"
            fi

            while ! (system_profiler SPUSBDataType 2> /dev/null | grep 'Manufacturer: Apple Inc.' >> /dev/null); do
                sleep 1
            done
        else
            if ! (lsusb 2> /dev/null | grep ' Apple, Inc.' >> /dev/null); then
                echo "[*] Waiting for device in normal mode"
            fi

            while ! (lsusb 2> /dev/null | grep ' Apple, Inc.' >> /dev/null); do
                sleep 1
            done
        fi
    elif [ "$1" = 'recovery' ]; then
        if [ "$os" = 'Darwin' ]; then
            if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (Recovery Mode):' >> /dev/null); then
                echo "[*] Waiting for device to reconnect in recovery mode"
            fi

            while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (Recovery Mode):' >> /dev/null); do
                sleep 1
            done
        else
            if ! (lsusb 2> /dev/null | grep ' Apple, Inc.' >> /dev/null); then
                echo "[*] Waiting for device to reconnect in recovery mode"
            fi

            while ! (lsusb 2> /dev/null | grep ' Apple, Inc.' >> /dev/null); do
                sleep 1
            done
        fi
        "$dir"/irecovery -c "setenv auto-boot true"
        "$dir"/irecovery -c "saveenv"
    fi
}

_check_dfu() {
    if [ "$os" = 'Darwin' ]; then
        if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode):' >> /dev/null); then
            echo "[-] Device didn't go in DFU mode, please rerun the script and try again"
            exit
        fi
    else
        if ! (lsusb 2> /dev/null | grep ' Apple Mobile Device (DFU Mode):' >> /dev/null); then
            echo "[-] Device didn't go in DFU mode, please rerun the script and try again"
            exit
        fi
    fi
}

_info() {
    if [ "$1" = 'recovery' ]; then
        echo $("$dir"/irecovery -q "$errout" | grep "$2" | sed "s/$2: //")
    elif [ "$1" = 'normal' ]; then
        echo $("$dir"/ideviceinfo "$errout" | grep "$2: " | sed "s/$2: //")
    fi
}

_pwn() {
    pwnd=$(_info recovery PWND)
    if [ "$pwnd" = "" ]; then
        echo "[*] Pwning device"
        "$dir"/gaster pwn > "$out"
        sleep 2
        "$dir"/gaster reset > "$out"
        sleep 1
    fi
}

_exit_handler() {
    if [ "$os" = 'Darwin' ]; then
        if [ ! "$1" = '--dfu' ]; then
            defaults write -g ignore-devices -bool false
            defaults write com.apple.AMPDevicesAgent dontAutomaticallySyncIPods -bool false
            killall Finder
        fi
    fi
    [ $? -eq 0 ] && exit
    echo "[-] An error occurred"
}
trap _exit_handler EXIT

# ===========
# Subcommands
# ===========

if [ "$1" = 'clean' ]; then
    rm -rf boot* work
    echo "[*] Removed the created boot files"
    exit
fi

# ============
# Dependencies
# ============

# Download gaster
if [ ! -e "$dir"/gaster ]; then
    curl -sLO https://nightly.link/verygenericname/gaster/workflows/makefile/main/gaster-"$os".zip
    unzip gaster-"$os".zip > "$out"
    mv gaster "$dir"/
    rm -rf gaster gaster-"$os".zip
fi

# Check for pyimg4
if ! python3 -c 'import pkgutil; exit(not pkgutil.find_loader("pyimg4"))'; then
    echo '[-] pyimg4 not installed. Press any key to install it, or press ctrl + c to cancel'
    read -n 1 -s
    python3 -m pip install pyimg4 > "$out"
fi

# ============
# Prep
# ============

# Update submodules
git submodule update --init --recursive > "$out"

# Re-create work dir if it exists, else, make it
if [ -e work ]; then
    rm -rf work
    mkdir work
else
    mkdir work
fi

chmod +x "$dir"/*
if [ "$os" = 'Darwin' ]; then
    xattr -r -d com.apple.quarantine "$dir"
fi

# ============
# Start
# ============

echo "palera1n | Version $version"
echo "Written by Nebula | Some code and ramdisk from Nathan | Patching commands and help from Mineek | Loader app by Amy"
echo ""

# Get device's iOS version from ideviceinfo if in normal mode
if [ "$1" = '--dfu' ]; then
    if [ -z "$2" ]; then
        echo "[-] When using --dfu, please pass the version you're device is on"
        exit
    else
        version=$2
    fi
else
    _wait normal
    version=$(_info normal ProductVersion)
    arch=$(_info normal CPUArchitecture)
    if [ "$arch" = "arm64e" ]; then
        echo "[-] palera1n doesn't, and never will, work on non-checkm8 devices"
        exit
    fi
    echo "Hello, $(_info normal ProductType) on $version!"
fi

# Put device into recovery mode, and set auto-boot to true
if [ ! "$1" = '--dfu' ]; then
    echo "[*] Switching device into recovery mode..."
    "$dir"/ideviceenterrecovery $(_info normal UniqueDeviceID) > "$out"
    _wait recovery
fi

# Grab more info
echo "[*] Getting device info..."
cpid=$(_info recovery CPID)
model=$(_info recovery MODEL)
deviceid=$(_info recovery PRODUCT)
ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$dir"/jq '.firmwares | .[] | select(.version=="'$version'") | .url' --raw-output)
rdipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$dir"/jq '.firmwares | .[] | select(.version=="14.8") | .url' --raw-output)

# Have the user put the device into DFU
if [ ! "$1" = '--dfu' ]; then
    echo "[*] Press any key when ready for DFU mode"
    read -n 1 -s
    step 3 "Get ready"
    step 4 "Hold volume down + side button" &
    sleep 3
    "$dir"/irecovery -c "reset"
    step 1 "Keep holding"
    step 10 'Release side button, but keep holding volume down'
    sleep 1
    
    _check_dfu
    echo "[*] Device entered DFU!"
fi
sleep 2

# ============
# Ramdisk
# ============

# Dump blobs, and install pogo if needed
if [ ! -f blobs/"$deviceid"-"$version".shsh2 ]; then
    mkdir -p blobs
    cd ramdisk

    chmod +x sshrd.sh
    ./sshrd.sh 14.8
    ./sshrd.sh boot

    # Execute the commands once the rd is booted
    "$dir"/iproxy 2222 22 &> "$out" >> "$out" &
    if ! ("$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost &> "$out" >> "$out"); then
        echo "[*] Waiting for the ramdisk to finish booting"
    fi

    while ! ("$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost &> "$out" >> "$out"); do
        sleep 1
    done

    echo "[*] Dumping blobs and installing Pogo"
    "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "mount_filesystems" > "$out"
    "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "cat /dev/rdisk1" > "$out" | dd of=dump.raw bs=256 count=$((0x4000)) > "$out"
    "$dir"/img4tool --convert -s blobs/"$deviceid"-"$version".shsh2 dump.raw > "$out"
    if [[ ! "$@" == *"--no-install"* ]]; then
        tipsdir=$("$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/find /mnt2/containers/Bundle/Application/ -name 'Tips.app'" 2> /dev/null)
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/bin/cp -rf /usr/local/bin/loader.app/* $tipsdir" > "$out"
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chown 33 $tipsdir/Tips" > "$out"
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chmod 755 $tipsdir/Tips $tipsdir/PogoHelper" > "$out"
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "chown 0 $tipsdir/PogoHelper" > "$out"
    fi
    sleep 2
    "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "reboot" > "$out"
    sleep 1
    killall iproxy
    _wait normal

    # Switch into recovery, and set auto-boot to true
    echo "[*] Switching device into recovery mode..."
    "$dir"/ideviceenterrecovery $(_info normal UniqueDeviceID) > "$out"
    _wait recovery

    # Have the user put the device into DFU
    echo "[*] Press any key when ready for DFU mode"
    read -n 1 -s
    step 3 "Get ready"
    step 4 "Hold volume down + side button" &
    sleep 3
    "$dir"/irecovery -c "reset"
    step 1 "Keep holding"
    step 10 'Release side button, but keep holding volume down'
    sleep 1

    # Check if device entered dfu
    _check_dfu
    echo "[*] Device entered DFU!"
    sleep 2
fi

# ============
# Boot create
# ============

# Actually create the boot files
if [ ! -e boot-"$deviceid" ]; then
    _pwn

    # Downloading files, and decrypting iBSS/iBEC
    mkdir boot-"$deviceid"
    cd work

    echo "[*] Converting blob"
    "$dir"/img4tool -e -s blobs/"$deviceid"-"$version".shsh2 -m IM4M > "$out"

    echo "[*] Downloading BuildManifest"
    "$dir"/pzb -g BuildManifest.plist "$ipswurl" > "$out"

    echo "[*] Downloading and decrypting iBSS"
    "$dir"/pzb -g "$(awk "/""$cpid""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipswurl" > "$out"
    "$dir"/gaster decrypt "$(awk "/""$cpid""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" iBSS.dec > "$out"

    echo "[*] Downloading and decrypting iBEC"
    "$dir"/pzb -g "$(awk "/""$cpid""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipswurl" > "$out"
    "$dir"/gaster decrypt "$(awk "/""$cpid""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" iBEC.dec > "$out"

    echo "[*] Downloading DeviceTree"
    "$dir"/pzb -g Firmware/all_flash/DeviceTree."$model".im4p "$ipswurl" > "$out"

    echo "[*] Downloading trustcache"
    if [ "$os" = 'Darwin' ]; then
       "$dir"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."StaticTrustCache"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | head -1)" "$ipswurl" > "$out"
    else
       "$dir"/pzb -g "$("$dir"/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:StaticTrustCache:Info:Path" | sed 's/"//g')" "$ipswurl" > "$out"
    fi

    echo "[*] Downloading kernelcache"
    "$dir"/pzb -g "$(awk "/""$cpid""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipswurl" > "$out"

    echo "[*] Patching and repacking iBSS/iBEC"
    "$dir"/iBoot64Patcher iBSS.dec iBSS.patched > "$out"
    "$dir"/iBoot64Patcher iBEC.dec iBEC.patched -b '-v keepsyms=1 debug=0xfffffffe panic-wait-forever=1 wdt=-1' > "$out"
    cd ..
    "$dir"/img4 -i work/iBSS.patched -o boot-"$deviceid"/iBSS.img4 -M work/IM4M -A -T ibss > "$out"
    "$dir"/img4 -i work/iBEC.patched -o boot-"$deviceid"/iBEC.img4 -M work/IM4M -A -T ibec > "$out"

    echo "[*] Patching and converting kernelcache"
    if [[ "$deviceid" == *'iPhone8'* ]]; then
        python3 -m pyimg4 im4p extract -i work/"$(awk "/""$model""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" -o work/kcache.raw --extra work/kpp.bin > "$out"
    else
        python3 -m pyimg4 im4p extract -i work/"$(awk "/""$model""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" -o work/kcache.raw > "$out"
    fi
    "$dir"/Kernel64Patcher work/kcache.raw work/kcache.patched -a -o > "$out"
    if [[ "$deviceid" == *'iPhone8'* ]]; then
        python3 -m pyimg4 im4p create -i work/kcache.patched -o work/krnlboot.im4p --extra work/kpp.bin -f rkrn --lzss > "$out"
    else
        python3 -m pyimg4 im4p create -i work/kcache.patched -o work/krnlboot.im4p -f rkrn --lzss > "$out"
    fi
    python3 -m pyimg4 img4 create -p work/krnlboot.im4p -o boot-"$deviceid"/kernelcache.img4 -m work/IM4M > "$out"

    echo "[*] Converting DeviceTree"
    "$dir"/img4 -i work/"$(awk "/""$model""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]//')" -o boot-"$deviceid"/devicetree.img4 -M work/IM4M -T rdtr > "$out"

    echo "[*] Patching and converting trustcache"
    if [ "$os" = 'Darwin' ]; then
        "$dir"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."StaticTrustCache"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | head -1 | sed 's/Firmware\///')" -o boot-"$deviceid"/trustcache.img4 -M work/IM4M -T rtsc > "$out"
    else
        "$dir"/img4 -i work/"$("$dir"/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:StaticTrustCache:Info:Path" | sed 's/"//g'| sed 's/Firmware\///')" -o boot-"$deviceid"/trustcache.img4 -M work/IM4M -T rtsc > "$out"
    fi
fi

# ============
# Boot device
# ============

sleep 2
_pwn
echo "[*] Booting device"
"$dir"/irecovery -f boot-"$deviceid"/iBSS.img4
sleep 3
"$dir"/irecovery -f boot-"$deviceid"/iBEC.img4
sleep 2
if [[ "$cpid" == *"0x80"* ]]; then
    "$dir"/irecovery -c "go"
    sleep 3
fi
"$dir"/irecovery -f other/bootlogo.img4
sleep 1
"$dir"/irecovery -f other/bootlogo.img4
"$dir"/irecovery -c 'setpicture 0x0'
"$dir"/irecovery -f boot-"$deviceid"/devicetree.img4
"$dir"/irecovery -c "devicetree"
"$dir"/irecovery -f boot-"$deviceid"/trustcache.img4
"$dir"/irecovery -c "firmware"
"$dir"/irecovery -f boot-"$deviceid"/kernelcache.img4
sleep 2
"$dir"/irecovery -c "bootx"

if [ "$os" = 'Darwin' ]; then
    if [ ! "$1" = '--dfu' ]; then
        defaults write -g ignore-devices -bool false
        defaults write com.apple.AMPDevicesAgent dontAutomaticallySyncIPods -bool false
        killall Finder
    fi
fi

rm -rf work rdwork
echo ""
echo "Done!"
echo "The device should now boot to iOS"
echo "If you already have ran palera1n, click Do All in the tools section of Pogo"
echo "If not, Pogo should be installed to Tips"
