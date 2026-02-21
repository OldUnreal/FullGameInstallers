# OldUnreal Linux Installers

This folder contains the OldUnreal installers for Unreal Gold, Unreal Tournament: GOTY, and Unreal Tournament 2004.

> [!IMPORTANT]
> The [Epic Games Terms of Service][tos] apply to the use and distribution of these games, and they supersede any other end user agreements that may accompany them.

## How to Install

> [!TIP]
> Using a **Steam Deck**, **Steam Machine** or **Steam Frame**? Switch to Desktop Mode (from the `[ STEAM ]` menu), and follow the instructions in **Method 1: .desktop file (Easy)**.

### Method 1: .desktop file (Easy)

> [!NOTE]
> This method will not allow you to change the default installation path. Use **Method 2: install script** if you wish to specify a different installation directory.
>
> GNOME users may need to move the `.desktop` file from their Downloads folder into either their Desktop or Applications folder.
>
> If you are having issues, please use **Method 2: install script**.

1. Download (_right click › Save Link As_) the .desktop file for the title you wish to install:
  - <a href="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-unreal.desktop" download>Unreal Gold</a>
  - <a href="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut99.desktop" download>Unreal Tournament: GOTY</a>
  - <a href="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut2004.desktop" download>Unreal Tournament 2004</a>

2. Double-click on the downloaded file. Select **[ Continue ]** or **[ Execute ]** if prompted.

3. Follow the instructions on screen.

### Method 2: install script

1. Download (_right click › Save Link As_) the installation script for the title you wish to install:
  - <a href="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-unreal.sh" download>Unreal Gold</a>
  - <a href="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut99.sh" download>Unreal Tournament: GOTY</a>
  - <a href="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut2004.sh" download>Unreal Tournament 2004</a>

2. Mark the downloaded script as executable by running `chmod +x install-title.sh` (replacing `install-title.sh` with the name of the script you downloaded).

3. Run the script: `./install-title.sh`

The installation scripts support various command line flags to customise your installation experience:

```
-d, --destination: Install directory. Will be created if it doesn't exist. (default: '~/.local/share/OldUnreal/TitleName')
--ui-mode: UI library to use during install.. Can be one of: 'auto', 'kdialog', 'zenity' and 'none' (default: 'auto')
--application-entry: Action to take when installing the XDG Application Entry.. Can be one of: 'install', 'prompt' and 'skip' (default: 'prompt')
--desktop-shortcut: Action to take when installing a desktop shortcut.. Can be one of: 'install', 'prompt' and 'skip' (default: 'prompt')
-e, --unrealed, --no-unrealed: Install UnrealEd (Windows, umu-launcher recommended). (off by default)
-k, --keep-installer-files, --no-keep-installer-files: Keep ISO and Patch files. (off by default)
-h, --help: Prints help
-v, --version: Prints version
```

## Dependencies

The script has the following dependencies:
  - `bash`
  - `coreutils`
  - `jq`
  - `tar`
  - `7zip` (alternatively: `7zip` \[Debian > bookworm\], `p7zip-full` \[Debian\ <= bookworm], `7zip-standalone-all` \[Fedora/RHEL\])
  - `curl` (or `wget`/`wget2` \[Fedora\])
  - `unshield` (UT2004 only)

Please refer to your distro's documentation on how to install these dependencies.

## UnrealEd

UnrealEd can be used via a Windows compatibility tool. To install the UnrealEd binaries, specify the `--unrealed` flag when running the install script.

This will install the Windows patch alongside the Linux patch, and create a bash script to launch UnrealEd. By default, the launcher script will try to use [umu-launcher][umu] if installed, and fallback to Proton or Wine if not.

> [!WARNING]
> UnrealEd is not tested under Linux. We recommend that you use Windows natively instead.

[tos]: https://legal.epicgames.com/en-US/epicgames/tos
[umu]: https://github.com/Open-Wine-Components/umu-launcher
