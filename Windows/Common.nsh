!macro COMMON_INSTALLER

# Setup name and description
Name "${GAME_NAME}"

Var KeepFiles

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

Section /o "Keep installer files"
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

!macroend