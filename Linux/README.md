# OldUnreal Linux Installers

This folder contains the OldUnreal installers for Unreal Gold, and Unreal Tournament: GOTY.

> [!IMPORTANT]
> The [Epic Games Terms of Service][tos] apply to the use and distribution of these games, and they supersede any other end user agreements that may accompany them.

## How to Install

> [!TIP]
> Using a **Steam Deck**, **Steam Machine** or **Steam Frame**? Switch to Desktop Mode (from the `[ STEAM ]` menu), and follow the instructions in **Method 1: .desktop file (Easy)**.

### Method 1: .desktop file (Easy)

> [!NOTE]
> This method will not allow you to change the default installation path. Use **Method 2: install script** if you wish to specify a different installation directory.

1. Download the .desktop file for the title you wish to install:
  - <a href="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-unreal.desktop" download>Unreal Gold</a>
  - <a href="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut99.desktop" download>Unreal Tournament: GOTY</a>

2. Double-click on the downloaded file. Select **[ Continue ]** or **[ Execute ]** if prompted.

3. Follow the instructions on screen.

### Method 2: install script

1. Download the installation script for the title you wish to install:
  - <a href="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-unreal.sh" download>Unreal Gold</a>
  - <a href="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut99.sh" download>Unreal Tournament: GOTY</a>

2. Mark the downloaded script as executable by running `chmod +x install-title.sh` (replacing `install-title.sh` with the name of the script you downloaded).

3. Run the script: `./install-title.sh`

The installation scripts support various command line flags to customise your installation experience:

```
-d, --destination: Install directory. Will be created if it doesn't exist. (default: '~/.local/share/OldUnreal/TitleName')
--ui-mode: UI library to use during install.. Can be one of: 'auto', 'kdialog', 'zenity' and 'none' (default: 'auto')
--application-entry: Action to take when installing the XDG Application Entry.. Can be one of: 'install', 'prompt' and 'skip' (default: 'prompt')
--desktop-shortcut: Action to take when installing a desktop shortcut.. Can be one of: 'install', 'prompt' and 'skip' (default: 'prompt')
-k, --keep-installer-files, --no-keep-installer-files: Keep ISO and Patch files. (off by default)
-h, --help: Prints help
-v, --version: Prints version
```

## Dependencies

The script has the following dependencies:
  - `bash`
  - `coreutils`
  - `jq`
  - `7zip` (alternatively: `p7zip-full` \[Debian\], `7zip-standalone-all` \[Fedora/RHEL\])
  - `curl` (or `wget`/`wget2` \[Fedora\])

Please refer to your distro's documentation on how to install these dependencies.

[tos]: https://legal.epicgames.com/en-US/epicgames/tos