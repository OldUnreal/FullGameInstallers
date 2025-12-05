#!/bin/bash

setVariables() {
	curr_path="$(pwd)"
	game_executable="unreal-bin-"
	icon_name="Unreal.ico"
	launcher_name="Unreal.desktop"
	game_name="Unreal Gold"
	game_folder='UnrealGold'
	iso_name='UNREAL_GOLD.ISO'
	iso_url="https://files.oldunreal.net/${iso_name}"
	latest_release='https://api.github.com/repos/OldUnreal/Unreal-testing/releases/tags/v227k_12'
	delete_folders="
DIRECTX7"
	delete_files="
AUTOPLAY.EXE
AUTORUN.INF
SETUP.EXE
UNINSTAL.EXE
"
	delete_extensions="
det
est
frt
int
itt
exe
dll
u
ini
"
	proper_case="
Help
Manuals
Maps
Music
Sounds
System
SystemLocalized
Textures
"
	if command -v xdg-user-dir >/dev/null 2>&1
	then
		desktop_dir=$(xdg-user-dir DESKTOP)
	else
		desktop_dir=~/Desktop
	fi
}

isInstalled() {
	if [ $# -ge 2 ]
	then
		debian_package="$1"
		others_package="$2"
	else
		debian_package="$1"
		others_package="$1"
	fi

	# Ubuntu/Debian/Mint/...
	if command -v dpkg > /dev/null 2>&1
	then
		dpkg -s "$debian_package" > /dev/null 2>&1
	# RHEL/CentOS/Fedora/...
	elif command -v rpm > /dev/null 2>&1
	then
		rpm -q "$others_package" > /dev/null 2>&1
	# arch/manjaro/...
	elif command -v pacman > /dev/null 2>&1
	then
		pacman -Qi "$others_package" > /dev/null 2>&1
	else
		echo "Unsupported package manager" >&2
		return 2
	fi
}

checkInstall() {
	if isInstalled "$@"
	then
		echo -e "\xE2\x9C\x94 $1"
	else
		echo "$1 missing"
		exit 0
	fi
}

checkDependencies() {
	echo "Checking dependencies..."
	checkInstall "coreutils"
	checkInstall "jq"
	checkInstall "tar"
	checkInstall "unzip"
	checkInstall "p7zip-full" "p7zip"
	checkInstall "wget"
}

getUnrealFiles() {
	if [ -d "./$game_folder" ]
	then
		echo -e "\xE2\x9C\x94 ${game_folder} directory exists already"
		return
	fi

	download=1
	if [ -f "./$iso_name" ]
	then
		filesize=$(stat --format=%s "./$iso_name")
		if [ "$filesize" -eq 676734976 ]
		then
			download=0
			echo -e "\xE2\x9C\x94 ${game_name} iso file already downloaded"
		fi
	fi

	if [ $download -eq 1 ]
	then
		echo "Downloading ${game_name} files..."
		wget -nv --show-progress "$iso_url"
		echo -e "\xE2\x9C\x94 ${game_name} files downloaded"
	fi

	mkdir "$game_folder"
	cd "$game_folder"

	echo "Extracting files..."
	7z x "../$iso_name" -y
	echo -e "\xE2\x9C\x94 Files extracted"
	cd ..
}

fixFolderCasing() {
	for folder_proper_case in $proper_case
	do
		upper_value=$(echo "$folder_proper_case" | tr '[:lower:]' '[:upper:]')
		if [ -d "$game_folder/$upper_value" ]
		then
			echo "Fixing folder case ${game_folder}/${folder_proper_case}"
			mv "${game_folder}/${upper_value}" "${game_folder}/${folder_proper_case}"
		fi
	done
}

deleteUnnecessaryFiles() {
	echo "Deleting unnecessary files"
	for folder in $delete_folders
	do
		if [ -d "$game_folder/$folder" ]
		then
			echo "Deleting folder ${game_folder}/${folder}"
			rm -rf "${game_folder}/${folder}"
		fi
	done
	for file in $delete_files
	do
		if [ -f "$game_folder/$file" ]
		then
			echo "Deleting file ${game_folder}/${file}"
			rm -f "${game_folder}/${file}"
		fi
	done
	for extension in $delete_extensions
	do
		echo "Deleting ${game_folder}/System/*.${extension}"
		rm ${game_folder}/System/*.${extension}
	done
	echo -e "\xE2\x9C\x94 Unnecessary files deleted"
}

# Patch 469d
getLatestRelease() {
	echo "Downloading latest patch release list..."
	wget -q -O patch_latest "$latest_release"
	patch_ver=$(jq -r '.tag_name' ./patch_latest)
	echo -e "\xE2\x9C\x94 Release list downloaded"
}

getArchitecture() {
	case $(uname -m) in
		x86_64)
			arc_suffix='amd64'
			system_suffix='64'
			url_download=$(jq -r '.assets[0].browser_download_url' ./patch_latest)
			;;
		aarch64)
			arc_suffix='arm64'
			system_suffix='ARM64'
			url_download=$(jq -r '.assets[1].browser_download_url' ./patch_latest)
			;;
		i386)
			arc_suffix='x86'
			system_suffix=''
			url_download=$(jq -r '.assets[2].browser_download_url' ./patch_latest)
			;;
		i686)
			arc_suffix='x86'
			system_suffix=''
			url_download=$(jq -r '.assets[2].browser_download_url' ./patch_latest)
			;;
		*)
			echo "Unknown architecture"
			exit 0
			;;
	esac
}

getPatch() {
	getLatestRelease
	getArchitecture
	patch_tar="OldUnreal-UTPatch-${patch_ver}-Linux-${arc_suffix}.tar.bz2"
	if [ -f "$patch_tar" ]
	then
		echo -e "\xE2\x9C\x94 Patch ${patch_ver} already downloaded"
	else
		echo "Downloading patch ${patch_ver}"
		wget -P "./$game_folder" -nv --show-progress "$url_download"
		echo -e "\xE2\x9C\x94 Patch downloaded"
		mv ./"${game_folder}"/*.tar.bz2 "$patch_tar"
	fi

	echo "Extracting and adding patch..."
	tar -xf "$patch_tar" -C "./${game_folder}/" --overwrite
	rm ./patch_latest
	echo -e "\xE2\x9C\x94 Patch added"
}

addLinks() {
	read -r -p "Add a .desktop entry?(Y/n) " desktop_entry
	read -r -p "Add a menu entry?(Y/n) " app_entry

	if [[ -z "$desktop_entry" ]]; then
		desktop_entry='y'
	fi
	if [[ -z "$app_entry" ]]; then
		app_entry='y'
	fi

	if [[ "$desktop_entry" =~ ^[Yy]$ || "$app_entry" =~ ^[Yy]$ ]]; then
		echo "Creating entry..."
		echo "[Desktop Entry]" > "$launcher_name"
		echo "Version=${patch_ver}" >> "$launcher_name"
		echo "Name=${game_name}" >> "$launcher_name"
		echo "Comment=${game_name}" >> "$launcher_name"
		echo "Exec=${curr_path}/${game_folder}/System${system_suffix}/${game_executable}${arc_suffix}" >> "$launcher_name"
		echo "Icon=${curr_path}/${game_folder}/System/Unreal.ico" >> "$launcher_name"
		echo "Terminal=false" >> "$launcher_name"
		echo "Type=Application" >> "$launcher_name"
		echo "Categories=ApplicationCategory;" >> "$launcher_name"
		chmod +x "$launcher_name"

		if [[ "$desktop_entry" =~ ^[Yy]$ ]]; then
			cp "$launcher_name" "$desktop_dir/"
			echo -e "\xE2\x9C\x94 .desktop entry created"
		fi

		if [[ "$app_entry" =~ ^[Yy]$ ]]; then
			cp "$launcher_name" ~/.local/share/applications/
			echo -e "\xE2\x9C\x94 Menu entry created"
		fi
		rm "$launcher_name"
	fi
}

deleteDownFiles() {
	read -r -p "Delete downloaded files?(Y/n) " del_download

	if [[ -z "$del_download" ]]; then
		del_download='y'
	fi

	if [[ "$del_download" =~ ^[Yy]$ ]]; then
		echo "Deleting downloaded files..."
		rm "./$iso_name"
		rm "$patch_tar"
		echo -e "\xE2\x9C\x94 Downloaded files deleted"
	fi
}

addUninstall() {
	echo "Creating uninstall script..."
	echo 'cd "$(dirname "$0")"' > uninstall.sh
	echo "rm -r '../${game_folder}'" >> uninstall.sh
	echo "rm -f '${desktop_dir}/${launcher_name}'" >> uninstall.sh
	echo "rm -f '~/.local/share/applications/${launcher_name}'" >> uninstall.sh
	chmod +x uninstall.sh
	mv uninstall.sh "./${game_folder}"
	echo -e "\xE2\x9C\x94 Uninstall script created"
}

setVariables
checkDependencies
getUnrealFiles
fixFolderCasing
deleteUnnecessaryFiles
getPatch
addLinks
deleteDownFiles
addUninstall

echo -e "\xE2\x9C\x94 Installation completed, execute ${game_folder}/System${system_suffix}/${game_executable}${arc_suffix} to play"
