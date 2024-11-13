# NSIS Script for Unreal Tournament Installation

!include "MUI2.nsh"

# Setup name and description
Name "Unreal Tournament GOTY"
OutFile "UT_GOTY.exe"
InstallDir "C:\UnrealTournament"

!define MUI_ABORTWARNING

# Display the license agreement page
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "NOTICE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

# Specify the license text file
LicenseData "NOTICE.txt"

# Define the installer's section
Section "Install"
	# Specify the additional space needed (in KB)
	AddSize 1363148	; Add 1.3GB to the required space

	# Create the installation directory
	SetOutPath "$INSTDIR"

	# Extract the entire "Installer" folder to the installation directory
	File /r "Installer"
	
	SetDetailsPrint none
	Delete "$INSTDIR\Installer\installed"
	Delete "$INSTDIR\Installer\closed"
	SetDetailsPrint both
	
	IfFileExists "$INSTDIR\Installer\UT_GOTY_CD1.iso" 0 download_iso
	
	Push "$INSTDIR\Installer\UT_GOTY_CD1.iso"
	Call FileSize
	Pop $0
	
	StrCmp $0 "649633792" run_script download_iso

download_iso:
	# Run install.bat from the extracted folder
	inetc::get /WEAKSECURITY /CAPTION "Downloading game ISO file" /RESUME "" /QUESTION "" "https://archive.org/download/ut-goty/UT_GOTY_CD1.iso" "$INSTDIR\Installer\UT_GOTY_CD1.iso" /END

run_script:	
	SetDetailsPrint both
	DetailPrint "Starting installation script. Please wait until it ends, and do not interrupt the process."
	
	SetDetailsPrint none
	ExecWait '"$INSTDIR\Installer\install.bat" ut99'
	SetDetailsPrint both
	
	IfFileExists "$INSTDIR\Installer\closed" 0 check_done
	MessageBox MB_OK "Installation failed: The installation process was terminated because the installer window was closed. Please restart the installer to complete the setup."
	Abort
	
check_done:	
	IfFileExists "$INSTDIR\Installer\installed" finish
	MessageBox MB_OK "Installation failed: The installation process did not complete successfully. Please ensure the installer is run to completion and try again."
	Abort

finish:	
	# Create Desktop shortcuts for Unreal Tournament and UnrealEd
	CreateShortcut "$DESKTOP\Unreal Tournament.lnk" "$INSTDIR\System\UnrealTournament.exe"
	CreateShortcut "$DESKTOP\UnrealEd.lnk" "$INSTDIR\System\UnrealEd.exe"

	# Create the folder "Unreal Tournament GOTY" in the user's startup folder
	CreateDirectory "$STARTMENU\Programs\Unreal Tournament GOTY"

	# Create shortcuts in the startup folder
	CreateShortcut "$STARTMENU\Programs\Unreal Tournament GOTY\Unreal Tournament.lnk" "$INSTDIR\System\UnrealTournament.exe"
	CreateShortcut "$STARTMENU\Programs\Unreal Tournament GOTY\UnrealEd.lnk" "$INSTDIR\System\UnrealEd.exe"

	# Create shortcuts in the install folder
	CreateShortcut "$INSTDIR\Unreal Tournament.lnk" "$INSTDIR\System\UnrealTournament.exe"
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