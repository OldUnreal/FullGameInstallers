#!/bin/bash

checkDependencies() {
	echo 'Checking dependencies...'
	if [ $( grep -c 'Arch Linux' /etc/os-release ) -gt 0 ]; then
		if pacman -Q coreutils &>/dev/null; then
			echo -e '\xE2\x9C\x94 coreutils'
		else
			echo 'coreutils missing'
			exit 0
		fi
		if pacman -Q jq &>/dev/null; then
			echo -e '\xE2\x9C\x94 jq'
		else
			echo 'jq missing'
			exit 0
		fi
		if pacman -Q tar &>/dev/null; then
			echo -e '\xE2\x9C\x94 tar'
		else
			echo 'tar missing'
			exit 0
		fi
		if pacman -Q unzip &>/dev/null; then
			echo -e '\xE2\x9C\x94 unzip'
		else
			echo 'unzip missing'
			exit 0
		fi
		if pacman -Q wget &>/dev/null; then
			echo -e '\xE2\x9C\x94 wget'
		else
			echo 'wget missing'
			exit 0
		fi
	fi
}

setVariables() {
	curr_path=$(pwd)
	fold_name='Unreal_tournament'
	zip_name='unreal_tournament.zip'
	ut99_zip=./$zip_name
	latest_release='https://api.github.com/repos/OldUnreal/UnrealTournamentPatches/releases/latest'
}

# Unreal tournament files from Archive.org
getUTFiles() {
	echo 'Downloading UT99 files...'
	wget -nv --show-progress 'https://archive.org/download/unreal-tournament-complete/Unreal%20Tournament.zip'
	echo -e '\xE2\x9C\x94 UT99 files downloaded'

	echo 'Extracting files...'
	mv ./'Unreal Tournament.zip' ./$zip_name
	unzip -q $ut99_zip
	mv ./'Unreal Tournament' ./$fold_name
	echo -e '\xE2\x9C\x94 Files extracted'
}

# Patch 469d
getLatestRelease() {
	echo 'Downloading latest patch release list...'
	wget -q -O patch_latest $latest_release
	patch_ver=$(cat ./patch_latest | jq -r '.tag_name')
	echo -e '\xE2\x9C\x94 Release list downloaded'
}

getArchitecture() {
	case $(uname -m) in
		x86_64)
    		arc_suffix='amd64'
    		system_suffix='64'
    		url_download=$(cat ./patch_latest | jq -r '.assets[0].browser_download_url')
    		;;
    	aarch64)
    		arc_suffix='arm64'
    		system_suffix='ARM64'
    		url_download=$(cat ./patch_latest | jq -r '.assets[1].browser_download_url')
    		;;
		i386)
			arc_suffix='x86'
    		system_suffix=''
    		url_download=$(cat ./patch_latest | jq -r '.assets[2].browser_download_url')
			;;
    	i686)
    		arc_suffix='x86'
    		system_suffix=''
    		url_download=$(cat ./patch_latest | jq -r '.assets[2].browser_download_url')
    		;;
    	*)
    		echo 'Unknown architecture'
    		exit 0
    		;; 	
	esac
}

getPatch() {
	getLatestRelease
	getArchitecture
	echo 'Downloading patch '$patch_ver
	wget -P ./$fold_name -nv --show-progress $url_download
	echo -e '\xE2\x9C\x94 Patch downloaded'

	echo 'Extracting and adding patch...'
	patch_tar=./$fold_name/'patch'$patch_ver'.tar.bz2'
	mv ./$fold_name/*.tar.bz2 $patch_tar
	tar -xf $patch_tar -C ./$fold_name/ --overwrite
	rm ./patch_latest
	echo -e '\xE2\x9C\x94 Patch added'
}

deleteWinFiles() {
	echo 'Removing windows files...'
	rm ./$fold_name/System/*.dll
	rm ./$fold_name/System/*.exe
	echo -e '\xE2\x9C\x94 Windows files removed'
}

addLinks() {
	read -p 'Add a .desktop entry?(Y/n) ' desktop_entry
	read -p 'Add a menu entry?(Y/n) ' app_entry
	
	if [[ -z $desktop_entry ]]; then
    	desktop_entry='y'
	fi
	if [[ -z $app_entry ]]; then
    	app_entry='y'
	fi

	if [[ $desktop_entry =~ ^[Yy]$ || $app_entry =~ ^[Yy]$ ]]; then
    	echo 'Creating entry...'
    	echo '[Desktop Entry]' > UT99.desktop
    	echo 'Version=469d' >> UT99.desktop
    	echo 'Name=Unreal Tournament' >> UT99.desktop
    	echo 'Comment=Unreal Tournament' >> UT99.desktop
    	echo 'Exec='$curr_path/$fold_name/'System'$system_suffix'/ut-bin-'$arc_suffix >> UT99.desktop
		echo 'Icon='$curr_path/$fold_name/'System/Unreal.ico' >> UT99.desktop
	    echo 'Terminal=false' >> UT99.desktop
	    echo 'Type=Application' >> UT99.desktop
	    echo 'Categories=ApplicationCategory;' >> UT99.desktop
	    chmod +x UT99.desktop

	    if [[ $desktop_entry =~ ^[Yy]$ ]]; then
	    	cp UT99.desktop ~/Desktop/
	    	echo -e '\xE2\x9C\x94 .desktop entry created'
	    fi
    
	    if [[ $app_entry =~ ^[Yy]$ ]]; then
	    	cp UT99.desktop ~/.local/share/applications/
	    	echo -e '\xE2\x9C\x94 Menu entry created'
	    fi
	    rm UT99.desktop
	fi
}

deleteDownFiles() {
	read -p 'Delete downloaded files?(Y/n) ' del_download
	
	if [[ -z $del_download ]]; then
    	del_download='y'
	fi

	if [[ $del_download =~ ^[Yy]$ ]]; then
		echo 'Deleting downloaded files...'
		rm $ut99_zip
		rm $patch_tar
		echo -e '\xE2\x9C\x94 Downloaded files deleted'
	fi
}

addUninstall() {
	echo 'Creating uninstall script...'
	echo 'rm -r ../'$fold_name > uninstall.sh
	echo 'rm ~/Desktop/UT99.desktop' >> uninstall.sh
	echo 'rm ~/.local/share/applications/UT99.desktop' >> uninstall.sh
	chmod +x uninstall.sh
	mv uninstall.sh ./$fold_name
	echo -e '\xE2\x9C\x94 Uninstall script created'
}


checkDependencies
setVariables
getUTFiles
getPatch
deleteWinFiles
addLinks
deleteDownFiles
addUninstall

echo -e '\xE2\x9C\x94 Installation completed, execute '$fold_name'/System'$system_suffix'/ut-bin-'$arc_suffix' to play'
