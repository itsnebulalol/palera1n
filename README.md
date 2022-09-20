# palera1n
iOS 15.0-15.7 **work in progress** semi-tethered checkm8 "jailbreak"

# What does this do?
It boots the device with AMFI patches. This is mainly a **developer** jailbreak. Eventually, I want it to automatically install Pogo by Amy. For now, it has to be installed with TrollStore. You can get an IPA [here](https://nightly.link/elihwyma/Pogo/workflows/build/main/Pogo.zip). There is **no tweak injection yet**.

**NOTE**: `sudo usbmuxd -p -f` should fix most USB issues on Linux. If not, compile and install [usbmuxd2](https://github.com/tihmstar/usbmuxd2), or use palera1n from DFU.

**WARNING**: As of now, this is a bit unstable (atleast just on A11). On my A11 device, it has the deep sleep bug while booted with palera1n, and will kernel panic, or just not wake up until force rebooted, about a minute after being in sleep mode. Patching AMFI also seems to log you out of iCloud?

**WARNING 2**: I am NOT responsible for any data loss. The user of this program accepts responsibility should something happen to their device. While nothing should happen, jailbreaking has risks in itself. If your device is stuck in recovery, please run `futurerestore --exit-recovery`, or use irecovery.

On A10 and A11, you **must disable your passcode**. On A10, this can be fixed in the future by implementing blackbird. On A11, we don't have a SEP exploit yet.

**Known working devices:**
- iPhone X (GSM)
- iPhone 7
- iPhone 6s (mine worked, but some others not)

# How to use
1. Install libimobiledevice
    - It's needed for `ideviceenterrecovery` and `ideviceinfo`
2. Clone this repo with `git clone https://github.com/itsnebulalol/palera1n && cd palera1n`
3. Prepare your blob for the **current version** you're on
4. Run `./palera1n.sh path/to/blob.shsh2`
    - \[A10+\] Before running, you **must** disable your passcode
    - If you want to start from DFU, run `./palera1n.sh path/to/blob.shsh2 --dfu <your iOS version here>`
5. Make sure your device is in normal mode, if you didn't start from DFU
6. Follow the steps
    - Right now, getting into DFU is steps for A11, please suppliment the steps for your device
7. Install Pogo through TrollStore, then hit Install in the Pogo app!
    - You can get a Pogo IPA from [here](https://nightly.link/elihwyma/Pogo/workflows/build/main/Pogo.zip)
    - You should now see Sileo on your homescreen, enjoy!
    - You'll have to uicache in the Pogo app every reboot

# Credits
- [Nathan](https://github.com/verygenericname) for a lot of the code from SSHRD_Script
    - The ramdisk that dumps blobs is a slimmed down version of SSHRD_Script
- [Mineek](https://github.com/mineek) for some of the patching and booting commands
- [Amy](https://github.com/elihwyma) for the Pogo app
- [nyuszika7h](https://github.com/nyuszika7h) for the script to get into DFU
- [the Procursus Team](https://github.com/ProcursusTeam) for the amazing bootstrap
