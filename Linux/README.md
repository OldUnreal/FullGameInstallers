# OldUnreal Linux Installers

The installers in this repository will automatically download game data and patches from the Internet.

To install:

1. Clone this repository or download a release bundle.
2. Run the corresponding installer in the `bin/` directory.

Note that by default, the game will be installed a subfolder of your current directory.

If you want to install the game at a different location, please specify the `--directory` (`-d`) flag.

The installer will detect if `zenity` is available, and will provide a UI during installation if it is available.

## Dependencies

The script has the following dependencies:
  - `bash`
  - `coreutils`
  - `jq`
  - `tar`
  - `unzip`
  - `p7zip-full` (alternatively: `p7zip` \[Arch\], `7zip-standalone-all` \[Fedora\])
  - `wget` (`wget2` \[Fedora\])

Please refer to your distro's documentation on how to install these dependencies.