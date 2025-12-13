# OldUnreal Linux Installers

The installers in this repository will automatically download game data and patches from the Internet.

To install:

1. Download the desired installer script.
2. Execute the script.

Note that by default, the game will be installed a subfolder of your current directory.

If you want to install the game at a different location, please specify the `--destination` (`-d`) flag.

The installer will detect if `zenity` or `kdialog` is available, and will provide a UI during installation if it is available.

## Dependencies

The script has the following dependencies:
  - `bash`
  - `coreutils`
  - `jq`
  - `7zip` (alternatively: `p7zip-full` \[Debian\], `7zip-standalone-all` \[Fedora/RHEL\])
  - `curl` (or `wget`/`wget2` \[Fedora\])

Please refer to your distro's documentation on how to install these dependencies.