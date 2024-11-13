# NSIS Script for Unreal Tournament Installation

!include "MUI2.nsh"

# Setup name and description
Name "Unreal Gold"
OutFile "Unreal_Gold.exe"
InstallDir "C:\Unreal"

!define MUI_ABORTWARNING

# Display the license agreement page
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "UNOTICE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

# Specify the license text file
LicenseData "UNOTICE.txt"

# Define the installer's section
Section "Install"
	# Specify the additional space needed (in KB)
	AddSize 1468006	; Add 1.4GB to the required space

	# Create the installation directory
	SetOutPath "$INSTDIR"

	# Extract the entire "Installer" folder to the installation directory
	File /r "Installer"
	
	SetDetailsPrint none
	Delete "$INSTDIR\Installer\installed"
	Delete "$INSTDIR\Installer\closed"
	SetDetailsPrint both
	
	IfFileExists "$INSTDIR\Installer\UNREAL_GOLD.ISO" 0 download_iso
	
	Push "$INSTDIR\Installer\UNREAL_GOLD.ISO"
	Call FileSize
	Pop $0
	
	StrCmp $0 "676734976" run_script download_iso

download_iso:
	# Run install.bat from the extracted folder
	inetc::get /WEAKSECURITY /CAPTION "Downloading game ISO file" /RESUME "" /QUESTION "" "https://archive.org/download/totallyunreal/UNREAL_GOLD.ISO" "$INSTDIR\Installer\UNREAL_GOLD.ISO" /END

run_script:	
	SetDetailsPrint both
	DetailPrint "Starting installation script. Please wait until it ends, and do not interrupt the process."
	
	SetDetailsPrint none
	ExecWait '"$INSTDIR\Installer\install.bat" ugold'
	SetDetailsPrint both
	
	IfFileExists "$INSTDIR\Installer\closed" 0 check_done
	MessageBox MB_OK "Installation failed: The installation process was terminated because the installer window was closed. Please restart the installer to complete the setup."
	Abort
	
check_done:	
	IfFileExists "$INSTDIR\Installer\installed" finish
	MessageBox MB_OK "Installation failed: The installation process did not complete successfully. Please ensure the installer is run to completion and try again."
	Abort

finish:	
	# Create Desktop shortcuts for Unreal Gold and UnrealEd
	CreateShortcut "$DESKTOP\Unreal Gold.lnk" "$INSTDIR\System\Unreal.exe"
	CreateShortcut "$DESKTOP\UnrealEd.lnk" "$INSTDIR\System\UnrealEd.exe"

	# Create the folder "Unreal Gold" in the user's startup folder
	CreateDirectory "$STARTMENU\Programs\Unreal Gold"

	# Create shortcuts in the startup folder
	CreateShortcut "$STARTMENU\Programs\Unreal Gold\Unreal Gold.lnk" "$INSTDIR\System\Unreal.exe"
	CreateShortcut "$STARTMENU\Programs\Unreal Gold\UnrealEd.lnk" "$INSTDIR\System\UnrealEd.exe"

	# Create shortcuts in the install folder
	CreateShortcut "$INSTDIR\Unreal Gold.lnk" "$INSTDIR\System\Unreal.exe"
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