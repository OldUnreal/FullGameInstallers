#!/bin/bash

# Pretty colors
BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

GAME_NAME="Unreal Tournament"
ISO_NAME="UT99"
USER_SUPPORT_DIR="$HOME/Library/Application Support/"

# Hardcoded URLs for game isos
ISO_URLS=(
	"https://files.oldunreal.net/UT_GOTY_CD1.ISO"
	"https://files2.oldunreal.net/UT_GOTY_CD1.ISO"
	"https://archive.org/download/ut-goty/UT_GOTY_CD1.iso"
)

ISO_HASH="e184984ca88f001c5ddd52035d76cd64e266e26c74975161b5ed72366c74704f"

TMP_ISO="/var/tmp/${ISO_NAME}_download.iso"
TMP_PARTIAL="${TMP_ISO}.partial"
MOUNT_POINT="/var/tmp/${ISO_NAME}Installer"

compute_sha256() {
	/usr/bin/shasum -a 256 "$1" | awk '{print $1}'
}

download_game() {
	rm -f "$TMP_ISO" "$TMP_PARTIAL"

	num_urls="${#ISO_URLS[@]}"

	# we should probably select one of the oldunreal URLs first and use
	# archive.org only as a fallback
	start_index=$(( RANDOM % num_urls ))

	for ((i = 0; i < num_urls; i++)); do
		index=$(( (start_index + i) % num_urls ))
		url="${ISO_URLS[$index]}"
		expected_hash="${ISO_HASH}"

		echo "Trying: $url (expected hash $expected_hash)"

		rm -f "$TMP_PARTIAL"

		# Download attempt
		if curl \
			   -L --fail --continue-at - \
			   --show-error --progress-bar \
			   -o "$TMP_PARTIAL" \
			   "$url"
		then
			mv "$TMP_PARTIAL" "$TMP_ISO"

			# Hash verification
			actual_hash="$(compute_sha256 "$TMP_ISO")"
			echo "Actual:   $actual_hash"

			if [ "$actual_hash" = "$expected_hash" ]; then
				echo "Hash OK for: $url"
				return 0
			else
				echo "Hash mismatch for $url — trying next"
				rm -f "$TMP_ISO"
			fi
		else
			echo "Failed to download from $url"
		fi
	done

	echo "All URLs failed or hashes did not match"
	return 1
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"

# step 0: force the user to accept the epic terms of service
clear

# Display EULA text
cat <<EOF

==================================================
     OldUnreal Unreal Tournament 99 Installer
==================================================

Welcome. You are about to begin the installation of Unreal Tournament.

The Epic Games Terms of Service apply to the use and distribution of this game, 
and they supersede any other end user agreements that may accompany the game.

You can read the Terms of Service here:
https://legal.epicgames.com/en-US/epicgames/tos

This installer uses SDL2. You can read its license here:
https://github.com/libsdl-org/SDL/blob/main/LICENSE.txt

By typing "yes", you agree to the Epic Games Terms of Service.
EOF

echo ""

# Prompt for acceptance
read -r -p "Do you accept the terms of service? (type 'yes' to continue): " reply

# Check their answer
if [[ "$reply" != "yes" ]]; then
	echo "Terms not accepted. Exiting."
	exit 1
fi

echo "Thank you. Continuing..."

# step 1: download the game iso
printf "${GREEN}>>> Downloading game${RESET}\n"
if download_game
then
	echo "ISO downloaded"
else
	printf "${RED}Download failed${RESET}\n"
	exit 1
fi

# step 2: mount the game iso
printf "${GREEN}>>> Mounting game image: ${TMP_ISO} => ${MOUNT_POINT}${RESET}\n"
# create a unique mount point name
if [ -d "$MOUNT_POINT" ]; then
	MOUNT_POINT="${MOUNT_POINT}_$$"
fi
mkdir -p "$MOUNT_POINT"
if /usr/bin/hdiutil attach "$TMP_ISO" -mountpoint "$MOUNT_POINT" -nobrowse -noverify -noautoopen
then
	echo "ISO mounted"
else
	printf "${RED}Mounting failed${RESET}\n"
	exit 1
fi

# step 3: move all assets into the application support dir
printf "${GREEN}>>> Moving game files to ${USER_SUPPORT_DIR}${GAME_NAME}${RESET}\n"
mkdir -p "${USER_SUPPORT_DIR}${GAME_NAME}"
cd "$MOUNT_POINT"
cp -r Help "${USER_SUPPORT_DIR}${GAME_NAME}/"
cp -r Maps "${USER_SUPPORT_DIR}${GAME_NAME}/"
cp -r Music "${USER_SUPPORT_DIR}${GAME_NAME}/"
cp -r Sounds "${USER_SUPPORT_DIR}${GAME_NAME}/"
cp -r Textures "${USER_SUPPORT_DIR}${GAME_NAME}/"

# delete textures that are also in the main app bundle
rm "${USER_SUPPORT_DIR}${GAME_NAME}/Textures/UWindowFonts.utx"
rm "${USER_SUPPORT_DIR}${GAME_NAME}/Textures/LadderFonts.utx"

/usr/bin/hdiutil detach "$MOUNT_POINT"

# step 4: use the embedded UCC to extract the maps
printf "${GREEN}>>> Extracting maps${RESET}\n"
cd "$USER_SUPPORT_DIR/$GAME_NAME/Maps"
for file in `ls -1 *.unr.uz`
do
	$APP_DIR/MacOS/UCC decompress "$USER_SUPPORT_DIR/$GAME_NAME/Maps/$file"
done
mv ../System/*.unr .

# step 5: delete temporary files
printf "${GREEN}>>> Cleaning up${RESET}\n"
rm *.unr.uz
cd ..

printf "${GREEN}The game assets are now installed.\nYou should now download and install the game patch.\nAfter that, you should be able to play${RESET}\n"

read -p "Press Enter to continue..."
