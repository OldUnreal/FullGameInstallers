!macro COMMON_INSTALLER

# Setup name and description
Name "${GAME_NAME}"

!define UNINSTALLER_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\OldUnreal_${GAME}"

Var KeepFiles
Var ProtocolHandler
Var UmodHandler
Var FromCD
Var DesktopLinks
Var StartMenuLinks

!include "WinVer.nsh"

!include "StrFunc.nsh"
; "Import"
${StrStr}
${StrSort}
${StrRep}

!define MUI_COMPONENTSPAGE_NODESC
!include "MUI2.nsh"

!define MUI_ABORTWARNING

# Display the license agreement page
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${NOTICE_FILE}"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

LicenseData "${NOTICE_FILE}"

Section "Create shortcuts on the Desktop"
	StrCpy $DesktopLinks "1"
SectionEnd

Section "Create a Start Menu folder with shortcuts"
	StrCpy $StartMenuLinks "1"
SectionEnd

Section "Install the uninstaller" SecUninstaller
	; Write the uninstaller executable to the installation directory
	WriteUninstaller "$INSTDIR\Uninstall.exe"
	
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "DisplayName" "${GAME_NAME}"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "DisplayIcon" "$INSTDIR\System\${GAME_EXE}"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "Publisher" "Epic Games"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "DisplayVersion" "OldUnreal Edition"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "DesktopLinks" "$DesktopLinks"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "StartMenuLinks" "$StartMenuLinks"
	WriteRegDWORD HKLM "${UNINSTALLER_KEY}" "NoModify" 1
SectionEnd

Section "Register the game as the handler for the unreal:// protocol"
	; Register game executable as handler for unreal:// protocol
	StrCpy $ProtocolHandler "1"
SectionEnd

Section "Register the game as the handler for the UMOD files"
	; Register game executable as handler for unreal:// protocol
	StrCpy $UmodHandler "1"
SectionEnd

Section /o "Install the game from a compatible CD, if one is found"
	; Leave on disk ISO and patch files, downloaded from internet
	StrCpy $FromCD "from_cd"
SectionEnd
	
Section /o "Keep the installer files"
	; Leave on disk ISO and patch files, downloaded from internet
	StrCpy $KeepFiles "keep_files"
SectionEnd

# Define the installer's section
Section
	# Specify the additional space needed (in KB)
	AddSize "${ADD_SIZE_BYTES}"	; Add 1.3GB to the required space

	# Create the installation directory
	SetOutPath "$INSTDIR"

	# Extract the entire "Installer" folder to the installation directory
	!ifdef BP4
		File /r "Installer"
	!else
		File /r /x "utbonuspack4-zip.7z" "Installer"
	!endif
	
	SetDetailsPrint none
	Delete "$INSTDIR\Installer\installed"
	Delete "$INSTDIR\Installer\closed"
	Delete "$INSTDIR\Installer\failed"
	SetDetailsPrint both
	
	Var /GLOBAL Failed
	Var /GLOBAL GetISO
	
	IfFileExists "$INSTDIR\Installer\${ISO_NAME}" 0 run_script
	
	Push "$INSTDIR\Installer\${ISO_NAME}"
	Call FileSize
	Pop $0
	
	StrCmp $0 "${ISO_SIZE_BYTES}" 0 run_script
	StrCpy $GetISO "exists+match"

run_script:	
	SetDetailsPrint both
	DetailPrint "Starting installation script. Please wait until it ends, and do not interrupt the process."
	
	FileOpen $1 "$INSTDIR\Installer\failed" w
	FileClose $1
	
	IfFileExists "$INSTDIR\Installer\failed" 0 +2
	StrCpy $Failed "created"
	
	SetDetailsPrint none
	ExecWait '"$INSTDIR\Installer\install.bat" ${GAME} $FromCD $KeepFiles'
	SetDetailsPrint both
	
	IfFileExists "$INSTDIR\Installer\failed" 0 check_closed
#	StrCmp $Failed "" check_closed 0
	
	MessageBox MB_YESNO|MB_ICONQUESTION "Failed to run the installer script. Do you want to run the limited fallback installer?" IDYES limited_fallback
	
	Goto check_closed
	
	; Limited fallback - begin
limited_fallback:
	DetailPrint "Failed to run the installer script. Starting limited fallback."
	
	StrCmp $FromCD "" +3 0
	DetailPrint "The limited fallback does not support installing the game from a CD. The ISO option will be used instead."
	MessageBox MB_OK "The limited fallback does not support installing the game from a CD. The ISO option will be used instead."
	
	StrCmp $GetISO "" 0 skip_download_iso
	inetc::get /WEAKSECURITY /CAPTION "Downloading game ISO file" /RESUME "" /QUESTION "" "${ISO_URL}" "$INSTDIR\Installer\${ISO_NAME}" /END
skip_download_iso:
	
	IfFileExists "$INSTDIR\Installer\${ISO_NAME}" 0 iso_not_found
	
	Push "$INSTDIR\Installer\${ISO_NAME}"
	Call FileSize
	Pop $0
	
	StrCmp $0 "${ISO_SIZE_BYTES}" 0 iso_wrong_size

	DetailPrint 'Unpacking game ISO...'
	nsExec::ExecToLog '"$INSTDIR\Installer\tools\7z.exe" x -aoa -o"$INSTDIR" -x@"$INSTDIR\Installer\skip.txt" "$INSTDIR\Installer\${ISO_NAME}"'
	
	StrCmp "${GAME}" "ut99" 0 skip_bp4
	DetailPrint 'Unpacking Bonus Pack 4...'	
	nsExec::ExecToLog '"$INSTDIR\Installer\tools\7z.exe" x -aoa -o"$INSTDIR" "$INSTDIR\Installer\utbonuspack4-zip.7z"'
skip_bp4:

	Var /GLOBAL WinVer
	StrCpy $WinVer "-Windows"
	
	StrCmp "${GAME}" "ut99" 0 skip_check_xp
	${If} ${AtMostWinXP} ; Running on XP or older. Surely not running on Vista. Maybe 98, or even 95.
		StrCpy $WinVer "-WindowsXP"
	${EndIf}
skip_check_xp:

	Delete "$INSTDIR\Installer\tmp"
	inetc::get /WEAKSECURITY /CAPTION "Downloading patch info" /RESUME "" /QUESTION "" "${PATCH_URL}" "$INSTDIR\Installer\tmp" /END
	
	; Strings limited in size to 1023 length so we goes to use 2 buffer of 500 symbols. $6 and $7
	IfFileExists "$INSTDIR\Installer\tmp" 0 patch_info_not_found
	FileOpen $5 "$INSTDIR\Installer\tmp" r
	
	StrCpy $6 ""
	FileRead $5 $7 500
	StrCmp $7 "" patch_info_empty 0

	Var /GLOBAL PatchUrl
json_read_loop:	
	StrCpy $6 $7
	FileRead $5 $7 500
	StrCpy $3 "$6$7"
	
	StrCmp $3 "" json_break_loop 0
	
json_begin_loop:
	${StrStr} $0 $3 '"browser_download_url":"https://'
	StrCpy $3 $0
	StrCmp $3 "" json_read_loop 0
	
	${StrStr} $0 $3 'https://'
	StrCpy $3 $0
	
	${StrSort} $0 $3 '' 'https://' '"' '0' '1' '0'
	StrCmp $0 "" json_begin_loop 0
	
	${StrStr} $2 $0 $WinVer
	StrCmp $2 "" json_begin_loop 0
	
	${StrStr} $2 $0 '.zip'
	StrCmp $2 "" json_begin_loop 0
	
	StrCpy $PatchUrl $0
json_break_loop:
	FileClose $5
	StrCmp $PatchUrl "" patch_url_empty 0
	DetailPrint 'Parsed patch ZIP URL: "$PatchUrl"'
	
	Delete "$INSTDIR\Installer\patch.zip"
	inetc::get /WEAKSECURITY /CAPTION "Downloading patch ZIP" /RESUME "" /QUESTION "" $PatchUrl "$INSTDIR\Installer\patch.zip" /END
	
	DetailPrint 'Unpacking patch ZIP...'
	nsExec::ExecToLog '"$INSTDIR\Installer\tools\7z.exe" x -aoa -o"$INSTDIR" "$INSTDIR\Installer\patch.zip"'
	
	DetailPrint 'Unpacking game files... '
	
	StrCpy $5 "0"
	FindFirst $0 $1 $INSTDIR\Maps\*.unr.uz
cnt_loop:
		StrCmp $1 "" cnt_done
		IntOp $5 $5 + 1
		FindNext $0 $1
		Goto cnt_loop
cnt_done:
	FindClose $0
	
	StrCpy $4 "0"
	FindFirst $0 $1 $INSTDIR\Maps\*.unr.uz
uz_loop:
		StrCmp $1 "" uz_done
		${StrStr} $3 $1 "."
		${StrRep} $2 $1 $3 ".unr"
		
		IntOp $6 $4 / $5
		DetailPrint 'Unpacking game files... $6%      $1   --->   $2'
		IntOp $4 $4 + 100
		IfFileExists "$INSTDIR\Maps\$2" +2 0
		nsExec::ExecToLog '"$INSTDIR\System\ucc.exe" decompress "..\Maps\$1"'

		IfFileExists "$INSTDIR\System\$2" 0 +2
		Rename "$INSTDIR\System\$2" "$INSTDIR\Maps\$2"
		IfFileExists "$INSTDIR\Maps\$2" 0 +2
		Delete "$INSTDIR\Maps\$1"
		
		FindNext $0 $1
		Goto uz_loop
uz_done:
	FindClose $0

	DetailPrint 'Special fixes...'
	IfFileExists "$INSTDIR\Maps\DM-Cybrosis][.unr" 0 +2
	CopyFiles "$INSTDIR\Maps\DM-Cybrosis][.unr" "$INSTDIR\Maps\DOM-Cybrosis][.unr"
	
	DetailPrint 'Alter game configuration...'

	StrCmp "${GAME}" "ut99" 0 skip_copy_ini
	CopyFiles "$INSTDIR\Installer\UnrealTournament.ini" "$INSTDIR\System\UnrealTournament.ini"
	CopyFiles "$INSTDIR\Installer\User.ini" "$INSTDIR\System\User.ini"
skip_copy_ini:

	DetailPrint 'Remove downloaded files...';
	StrCmp $KeepFiles "" 0 skip_remove_files
	
	Delete "$INSTDIR\Installer\${ISO_NAME}"
	Delete "$INSTDIR\Installer\tmp"
	Delete "$INSTDIR\Installer\patch.zip"
skip_remove_files:	

	GoTo finish	
	
	Var /GLOBAL FailReason
	
iso_not_found:
	StrCmp $FailReason "" 0 +2
	StrCpy $FailReason "ISO not found"
	
iso_wrong_size:
	StrCmp $FailReason "" 0 +2
	StrCpy $FailReason "ISO wrong size"
	
patch_info_not_found:
	StrCmp $FailReason "" 0 +2
	StrCpy $FailReason "Patch info not found at ${PATCH_URL}"
	
patch_info_empty:
	StrCmp $FailReason "" 0 +2
	StrCpy $FailReason "Patch info empty from ${PATCH_URL}"
	
patch_url_empty:
	StrCmp $FailReason "" 0 +2
	StrCpy $FailReason "Patch url empty from ${PATCH_URL}"
	
	DetailPrint "$FailReason"
	MessageBox MB_OK "Installation failed: The installation process did not complete successfully. Please ensure the installer is run to completion and try again. $\r$\n$\r$\n$FailReason"
	Abort
		
	; Limited fallback - end
	
check_closed:
	IfFileExists "$INSTDIR\Installer\closed" 0 check_done
	MessageBox MB_OK "Installation failed: The installation process was terminated because the installer window was closed. Please restart the installer to complete the setup."
	Abort
	
check_done:	
	IfFileExists "$INSTDIR\Installer\installed" finish
	MessageBox MB_OK "Installation failed: The installation process did not complete successfully. Please ensure the installer is run to completion and try again."
	Abort

finish:	
	# Create Desktop shortcuts for fame excutable and UnrealEd
	StrCmp $DesktopLinks "" +3 0
	CreateShortcut "$DESKTOP\${GAME_NAME_SHORT}.lnk" "$INSTDIR\System\${GAME_EXE}"
	CreateShortcut "$DESKTOP\UnrealEd.lnk" "$INSTDIR\System\UnrealEd.exe"

	# Create the folder in the user's start menu folder
	StrCmp $StartMenuLinks "" +4 0
	CreateDirectory "$STARTMENU\Programs\${GAME_NAME}"
	CreateShortcut "$STARTMENU\Programs\${GAME_NAME}\${GAME_NAME_SHORT}.lnk" "$INSTDIR\System\${GAME_EXE}"
	CreateShortcut "$STARTMENU\Programs\${GAME_NAME}\UnrealEd.lnk" "$INSTDIR\System\UnrealEd.exe"

	# Create shortcuts in the install folder
	CreateShortcut "$INSTDIR\${GAME_NAME_SHORT}.lnk" "$INSTDIR\System\${GAME_EXE}"
	CreateShortcut "$INSTDIR\UnrealEd.lnk" "$INSTDIR\System\UnrealEd.exe"

	WriteRegStr HKLM "SOFTWARE\WOW6432Node\Unreal Technology\Installed Apps\${PRODUCT}" "Folder" '$INSTDIR'
	WriteRegStr HKLM "SOFTWARE\Unreal Technology\Installed Apps\${PRODUCT}" "Folder" '$INSTDIR'
	
	StrCmp $ProtocolHandler "" skip_protocol_handler

	WriteRegStr HKCR "unreal" "" "URL:unreal Protocol"
	WriteRegStr HKCR "unreal" "URL Protocol" ""
	WriteRegStr HKCR "unreal\shell\open\command" "" '"$INSTDIR\System\${GAME_EXE}" "%1"'
skip_protocol_handler:

	StrCmp $UmodHandler "" skip_umod_handler

	WriteRegStr HKCR ".umod" "" "${GAME}.UModFile"
	WriteRegStr HKCR "${GAME}.UModFile" "" "UMod File"
	WriteRegStr HKCR "${GAME}.UModFile\DefaultIcon" "" "$INSTDIR\System\Setup.exe,0"
	WriteRegStr HKCR "${GAME}.UModFile\shell\open\command" "" '"$INSTDIR\System\Setup.exe" "%1"'
skip_umod_handler:

SectionEnd


Function FileSize
 
	Exch $0
	Push $1
	FileOpen $1 $0 "r"
	FileSeek $1 0 END $0
	FileClose $1
	Pop $1
	Exch $0
 
FunctionEnd

; The uninstaller section
Section Uninstall
	; Ask for confirmation before proceeding
	MessageBox MB_YESNO|MB_ICONQUESTION "Are you sure you want to completely remove ${GAME_NAME}?$\r$\n$\r$\nAll files and registry entries will be removed.$\r$\n$\r$\nThis includes all content in the game folder, including custom files such as maps, textures, mods, mutators, save games, demo files, etc." IDYES remove
	
	DetailPrint "User canceled the uninstallation process."
	Abort "User canceled the uninstallation process."

remove:
	ReadRegStr $0 HKLM "${UNINSTALLER_KEY}" "DesktopLinks"
	StrCmp $0 "" +3 0
	Delete "$DESKTOP\${GAME_NAME_SHORT}.lnk"
	Delete "$DESKTOP\UnrealEd.lnk"

	ReadRegStr $0 HKLM "${UNINSTALLER_KEY}" "StartMenuLinks"
	StrCmp $0 "" +4 0
	Delete "$STARTMENU\Programs\${GAME_NAME}\${GAME_NAME_SHORT}.lnk"
	Delete "$STARTMENU\Programs\${GAME_NAME}\UnrealEd.lnk"
	RMDir "$STARTMENU\Programs\${GAME_NAME}"
	
	ReadRegStr $0 HKLM "SOFTWARE\WOW6432Node\Unreal Technology\Installed Apps\${PRODUCT}" "Folder"
	StrCmp $0 '$INSTDIR' 0 +2
	DeleteRegKey HKLM "SOFTWARE\WOW6432Node\Unreal Technology\Installed Apps\${PRODUCT}"
	
	ReadRegStr $0 HKLM "SOFTWARE\Unreal Technology\Installed Apps\${PRODUCT}" "Folder"
	StrCmp $0 '$INSTDIR' 0 +2
	DeleteRegKey HKLM "SOFTWARE\Unreal Technology\Installed Apps\${PRODUCT}"

	ReadRegStr $0 HKCR "unreal\shell\open\command" ""
	StrCmp $0 '"$INSTDIR\System\${GAME_EXE}" "%1"' 0 +2
	DeleteRegKey HKCR "unreal"
	
	ReadRegStr $0 HKCR "${GAME}.UModFile\shell\open\command" ""
	StrCmp $0 '"$INSTDIR\System\${GAME_EXE}" "%1"' 0 skip_unreg_umod
	DeleteRegKey HKCR "${GAME}.UModFile"
	
	ReadRegStr $0 HKCR ".umod" ""
	StrCmp $0 '${GAME}.UModFile' 0 +2
	DeleteRegValue HKCR ".umod" ""
skip_unreg_umod:
	
	; Remove registry entries for the uninstaller registration
	DeleteRegKey HKLM "${UNINSTALLER_KEY}"
	
	; Finally remove the installation directory
	RMDir /r "$INSTDIR"
SectionEnd

!macroend