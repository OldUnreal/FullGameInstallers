!macro COMMON_INSTALLER

# Setup name and description
Name "${GAME_NAME}"

!define UNINSTALLER_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\OldUnreal_${GAME}"

Var KeepFiles

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

Section "Install Uninstaller" SecUninstaller
; Write the uninstaller executable to the installation directory
	WriteUninstaller "$INSTDIR\Uninstall.exe"
	
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "DisplayName" "${GAME_NAME}"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "DisplayIcon" "$INSTDIR\System\${GAME_EXE}"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "Publisher" "Epic Games"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "DisplayVersion" "OldUnreal Edition"
	WriteRegDWORD HKLM "${UNINSTALLER_KEY}" "NoModify" 1
SectionEnd

Section "Register as handler for unreal:// protocol"
; Register game executable as handler for unreal:// protocol
	WriteRegStr HKCR "unreal" "" "URL:unreal Protocol"
	WriteRegStr HKCR "unreal" "URL Protocol" ""
	WriteRegStr HKCR "unreal\shell\open\command" "" '"$INSTDIR\System\${GAME_EXE}" "%1"'
SectionEnd
	
Section /o "Keep installer files"
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
	SetDetailsPrint both
	
	IfFileExists "$INSTDIR\Installer\${ISO_NAME}" 0 download_iso
	
	Push "$INSTDIR\Installer\${ISO_NAME}"
	Call FileSize
	Pop $0
	
	StrCmp $0 "${ISO_SIZE_BYTES}" run_script download_iso

download_iso:
	# Run install.bat from the extracted folder
	inetc::get /WEAKSECURITY /CAPTION "Downloading game ISO file" /RESUME "" /QUESTION "" "${ISO_URL}" "$INSTDIR\Installer\${ISO_NAME}" /END

run_script:	
	SetDetailsPrint both
	DetailPrint "Starting installation script. Please wait until it ends, and do not interrupt the process."
	
	SetDetailsPrint none
	ExecWait '"$INSTDIR\Installer\install.bat" ${GAME} $KeepFiles'
	SetDetailsPrint both
	
	IfFileExists "$INSTDIR\Installer\closed" 0 check_done
	MessageBox MB_OK "Installation failed: The installation process was terminated because the installer window was closed. Please restart the installer to complete the setup."
	Abort
	
check_done:	
	IfFileExists "$INSTDIR\Installer\installed" finish
	MessageBox MB_OK "Installation failed: The installation process did not complete successfully. Please ensure the installer is run to completion and try again."
	Abort

finish:	
	# Create Desktop shortcuts for fame excutable and UnrealEd
	CreateShortcut "$DESKTOP\${GAME_NAME_SHORT}.lnk" "$INSTDIR\System\${GAME_EXE}"
	CreateShortcut "$DESKTOP\UnrealEd.lnk" "$INSTDIR\System\UnrealEd.exe"

	# Create the folder in the user's start menu folder
	CreateDirectory "$STARTMENU\Programs\${GAME_NAME}"

	# Create shortcuts in the start menu folder
	CreateShortcut "$STARTMENU\Programs\${GAME_NAME}\${GAME_NAME_SHORT}.lnk" "$INSTDIR\System\${GAME_EXE}"
	CreateShortcut "$STARTMENU\Programs\${GAME_NAME}\UnrealEd.lnk" "$INSTDIR\System\UnrealEd.exe"

	# Create shortcuts in the install folder
	CreateShortcut "$INSTDIR\${GAME_NAME_SHORT}.lnk" "$INSTDIR\System\${GAME_EXE}"
	CreateShortcut "$INSTDIR\UnrealEd.lnk" "$INSTDIR\System\UnrealEd.exe"

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
	MessageBox MB_YESNO|MB_ICONQUESTION "Are you sure you want to completely remove ${GAME_NAME}?$\r$\n$\r$\nAll files and registry entries will be removed.$\r$\n$\r$\nThis includes all content in the game folder, including custom files such as maps, textures, mods, mutators, save games, demo files, etc." IDNO skip

	Delete "$DESKTOP\${GAME_NAME_SHORT}.lnk"
	Delete "$DESKTOP\UnrealEd.lnk"

	Delete "$STARTMENU\Programs\${GAME_NAME}\${GAME_NAME_SHORT}.lnk"
	Delete "$STARTMENU\Programs\${GAME_NAME}\UnrealEd.lnk"
	
	RMDir "$STARTMENU\Programs\${GAME_NAME}"
	
	ReadRegStr $0 HKCR "unreal\shell\open\command" ""
	
	; Compare the registry value with the expected command.
	StrCmp $0 '"$INSTDIR\System\${GAME_EXE}" "%1"' protocolRegistered protocolNotRegistered
	
	protocolRegistered:
	DeleteRegKey HKCR "unreal"
	Goto protocolNotRegistered
	
	protocolNotRegistered:
	; Remove registry entries for the uninstaller registration
	DeleteRegKey HKLM "${UNINSTALLER_KEY}"
	
	; Finally remove the installation directory
	RMDir /r "$INSTDIR"
	Goto done
	
	skip:
	; If user clicked NO, abort uninstallation
	DetailPrint "User canceled the uninstallation process."
	Abort

	done:
SectionEnd

!macroend