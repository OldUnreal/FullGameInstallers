#!/bin/bash

# Pretty colors
BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

GAME_NAME="UT2004"
USER_SUPPORT_DIR="$HOME/Library/Application Support/"

# Hardcoded URLs for game isos
ISO_URLS=(
	"https://files.oldunreal.net/UT2004.ISO"
	"https://files2.oldunreal.net/UT2004.ISO"
	"https://archive.org/download/ut-2004/UT2004.ISO"
)

ISO_HASHES=(
	"43e9182ae20bcbc0f6f4588fee6c1b336c261f1465403118a1973b09b1a22541"
	"43e9182ae20bcbc0f6f4588fee6c1b336c261f1465403118a1973b09b1a22541"
	"7ae95242aa23d5e31b353811e1e920a4377fa53cf728b8edcb17006b7f3c4e97"
)

TMP_ISO="/var/tmp/${GAME_NAME}_download.iso"
TMP_PARTIAL="${TMP_ISO}.partial"
MOUNT_POINT="/var/tmp/${GAME_NAME}Installer"

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
		expected_hash="${ISO_HASHES[$index]}"

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
    OldUnreal Unreal Tournament 2004 Installer
==================================================

Welcome. You are about to begin the installation of Unreal Tournament 2004.

The Epic Games Terms of Service apply to the use and distribution of this game, 
and they supersede any other end user agreements that may accompany the game.

You can read the Terms of Service here:
https://legal.epicgames.com/en-US/epicgames/tos

This installer uses unshield. You can find its license here:
https://github.com/twogood/unshield?tab=MIT-1-ov-file#readme

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

# step 3: move all cab and hdr files into the application support dir
mkdir -p "${USER_SUPPORT_DIR}${GAME_NAME}"
mkdir -p "${USER_SUPPORT_DIR}${GAME_NAME}.tmp"
cd "$MOUNT_POINT"
for file in `find . -iname "*.cab" -or -iname "*.hdr"`; do
	printf "${GREEN}>>> Moving $file => ${USER_SUPPORT_DIR}${GAME_NAME}.tmp/${RESET}\n"
	cp $file "${USER_SUPPORT_DIR}${GAME_NAME}.tmp/"
done

# step 4: use the embedded unshield to extract the cab files
printf "${GREEN}>>> Extracting game files${RESET}\n"
cd "$USER_SUPPORT_DIR/$GAME_NAME.tmp"
/usr/bin/hdiutil detach "$MOUNT_POINT"
if $APP_DIR/MacOS/unshield x *.hdr
then
	echo "Extraction succeeded"
else
	printf "${RED}Extraction failed${RESET}\n"
	exit 1
fi

# step 5: move files to the actual support dir
printf "${GREEN}>>> Moving game files to ${USER_SUPPORT_DIR}${GAME_NAME}${RESET}\n"
cp -r All_Animations ../$GAME_NAME/Animations
cp -r All_Benchmark ../$GAME_NAME/Benchmark
cp -r All_ForceFeedback ../$GAME_NAME/ForceFeedback
cp -r All_Help ../$GAME_NAME/Help
cp -r All_KarmaData ../$GAME_NAME/KarmaData
cp -r All_Maps ../$GAME_NAME/Maps
cp -r All_Music ../$GAME_NAME/Music
cp -r All_StaticMeshes ../$GAME_NAME/StaticMeshes
cp -r All_Textures ../$GAME_NAME/Textures
cp -r All_Web ../$GAME_NAME/Web
mkdir -p ../$GAME_NAME/Sounds/
for file in `find . -iname "*.uax"`; do
	cp $file ../$GAME_NAME/Sounds
done

# step 5: delete temporary files
printf "${GREEN}>>> Cleaning up${RESET}\n"
cd ..
rm -rf "$USER_SUPPORT_DIR$GAME_NAME.tmp"

printf "${GREEN}The game assets are now installed.\nYou should now download and install the game patch.\nAfter that, you should be able to play${RESET}\n"

read -p "Press Enter to continue..."
