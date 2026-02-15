!macro COMMON_INSTALLER

# Setup name and description
Name "${GAME_NAME}"

!define UNINSTALLER_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\OldUnreal_${GAME}"
!define UNINST_EXE "$INSTDIR\Uninstall_${GAME}.exe"
!define UNINST_INI "$INSTDIR\Uninstall_${GAME}.ini"

Var KeepFiles
Var ProtocolHandler
Var UmodHandler
Var FromCD
Var DesktopLinks
Var StartMenuLinks

Var PreInstallDirList
Var NewDirsList

!include "WinVer.nsh"

!include "StrFunc.nsh"
; "Import"
${StrStr}
${StrSort}
${StrRep}
!include "WordFunc.nsh"

!define MUI_COMPONENTSPAGE_NODESC
!include "MUI2.nsh"

!define MUI_ABORTWARNING

!define MUI_LICENSEPAGE_TEXT_BOTTOM "You must accept the Epic Games Terms of Service to continue."

!define MUI_LICENSEPAGE_RADIOBUTTONS
!define MUI_LICENSEPAGE_RADIOBUTTONS_TEXT_ACCEPT  "I accept the Epic Games Terms of Service"
!define MUI_LICENSEPAGE_RADIOBUTTONS_TEXT_DECLINE "I do not accept the Epic Games Terms of Service"

# Display the license agreement page
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${NOTICE_FILE}"
!insertmacro MUI_PAGE_COMPONENTS

; Hook this function to the "Next" button of the Directory Page
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE VerifyInstallDirectory

Function VerifyInstallDirectory
	; 1. If directory doesn't exist yet, it's safe (it's new)
	IfFileExists "$INSTDIR\*.*" check_contents is_safe

	check_contents:
	; 2. Check if the directory is actually empty (ignoring . and ..)
	Push $R0 ; Handle
	Push $R1 ; Filename

	FindFirst $R0 $R1 "$INSTDIR\*.*"
	
	loop_check:
		StrCmp $R1 "" is_empty      ; End of list? Then it's empty.
		StrCmp $R1 "." next_check   ; Skip current dir marker
		StrCmp $R1 ".." next_check  ; Skip parent dir marker

		; IF WE ARE HERE, WE FOUND A FILE OR FOLDER!
		; The directory is NOT empty.
		Goto warn_user

	next_check:
		FindNext $R0 $R1
		Goto loop_check

	is_empty:
		FindClose $R0
		Pop $R1
		Pop $R0
		Goto is_safe

	warn_user:
		FindClose $R0
		Pop $R1
		Pop $R0

		; 3. THE EXPLICIT WARNING
		MessageBox MB_YESNO|MB_ICONEXCLAMATION|MB_DEFBUTTON2 \
		"WARNING: The selected folder is NOT EMPTY!$\n$\n\
		Current Target: $INSTDIR$\n$\n\
		If you continue:$\n\
		  1. Files will be placed EXACTLY in this folder.$\n\
		  2. NO SUBFOLDER (like '\${GAME_NAME_SHORT}') will be created.$\n\
		  3. Game files will be mixed with existing files.$\n$\n\
		Are you absolutely sure you want to install here?" \
		IDYES is_safe

		; If user clicked NO (or closed the box), stay on the page
		Abort

	is_safe:
FunctionEnd

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

LicenseData "${NOTICE_FILE}"

# Define the installer's section
Section
	Call SnapshotExistingDirs

	# Create the installation directory
	SetOutPath "$INSTDIR"

	# Extract the entire "Installer" folder to the installation directory
	!ifdef BP4
		File /r "Installer"
	!else
		File /r /x "utbonuspack4-zip.7z" "Installer"
	!endif
SectionEnd

Section "Create shortcuts on the Desktop"
	StrCpy $DesktopLinks "1"
SectionEnd

Section "Create a Start Menu folder with shortcuts"
	StrCpy $StartMenuLinks "1"
SectionEnd

Section "Install the uninstaller" SecUninstaller
	; Write the uninstaller executable to the installation directory
	WriteUninstaller "${UNINST_EXE}"
	
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "DisplayName" "${GAME_NAME}"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "UninstallString" "${UNINST_EXE}"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "DisplayIcon" "$INSTDIR\System\${GAME_EXE}"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "Publisher" "Epic Games"
	WriteRegStr HKLM "${UNINSTALLER_KEY}" "DisplayVersion" "OldUnreal Edition"
	WriteINIStr "${UNINST_INI}" "Uninstall" "InstallPath" "$INSTDIR"
	WriteINIStr "${UNINST_INI}" "Uninstall" "DesktopLinks" "$DesktopLinks"
	WriteINIStr "${UNINST_INI}" "Uninstall" "StartMenuLinks" "$StartMenuLinks"
	WriteRegDWORD HKLM "${UNINSTALLER_KEY}" "NoModify" 1
SectionEnd

Section "Register the game as the handler for the ${PROTOCOL}:// protocol"
	StrCpy $ProtocolHandler "1"
SectionEnd

Section "Register the game as the handler for the ${UMOD} files"
	StrCpy $UmodHandler "1"
SectionEnd

!ifndef DENY_FROM_CD
Section /o "Install the game from a compatible CD, if one is found"
	; Leave on disk ISO and patch files, downloaded from internet
	StrCpy $FromCD "from_cd"
SectionEnd
!endif
	
Section /o "Keep the installer files"
	; Leave on disk ISO and patch files, downloaded from internet
	StrCpy $KeepFiles "keep_files"
SectionEnd

;--------------------------------
; Visual C++ Redistributable x86
;--------------------------------
Section "Visual C++ Redistributable (x86)"
	; Check if x86 runtime is already installed
	; Returns 1 if installed
	ReadRegDWORD $0 HKLM "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86" "Installed"
	
	; If $0 == 1, jump to Skip label. Otherwise continue.
	IntCmp $0 1 VCRedist86_Skip 0 0

	DetailPrint "Installing Visual C++ Redistributable (x86)..."
	
	; Run silent, no restart
	ExecWait '"$INSTDIR\Installer\redist\vc_redist.x86.exe" /install /passive /norestart' $0
	
	; Check if reboot is required (Exit Code 3010)
	IntCmp $0 3010 VCRedist86_Reboot 0 0
	Goto VCRedist86_Done

VCRedist86_Reboot:
	SetRebootFlag true
	Goto VCRedist86_Done

VCRedist86_Skip:
	DetailPrint "VCRedist (x86) is already installed."

VCRedist86_Done:
SectionEnd

;--------------------------------
; Visual C++ Redistributable x64
;--------------------------------
Section "Visual C++ Redistributable (x64)" 
	; Check if we are on a 64-bit OS first using standard NSIS instruction
	; If simple string is empty, we are likely on 32-bit
	; (LogicLib usually handles this better, but here is a simple workaround)
	; Assuming modern Game installer running on x64 OS:

	; Check if x64 runtime is already installed
	ReadRegDWORD $0 HKLM "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" "Installed"
	
	; If $0 == 1, jump to Skip
	IntCmp $0 1 VCRedist64_Skip 0 0

	DetailPrint "Installing Visual C++ Redistributable (x64)..."
	
	ExecWait '"$INSTDIR\Installer\redist\vc_redist.x64.exe" /install /passive /norestart' $0
	
	; Check for 3010 (Reboot required)
	IntCmp $0 3010 VCRedist64_Reboot 0 0
	Goto VCRedist64_Done

VCRedist64_Reboot:
	SetRebootFlag true
	Goto VCRedist64_Done

VCRedist64_Skip:
	DetailPrint "VCRedist (x64) is already installed."

VCRedist64_Done:
SectionEnd

;--------------------------------
; DirectX (Offline)
;--------------------------------
Section "DirectX Runtimes" 
	DetailPrint "Updating DirectX components..."
	
	; Run DXSETUP silent
	ExecWait '"$INSTDIR\Installer\redist\dxwebsetup.exe" /q'
SectionEnd

# Define the installer's section
Section
	# Specify the additional space needed (in KB)
	AddSize "${ADD_SIZE_KB}"	; Add 1.3GB to the required space
	
	!ifdef DENY_FROM_CD
		StrCpy $FromCD ""
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
	Call FileSizeIso
	Pop $0
	
	StrCmp $0 "0" run_script 0
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
	
	IfFileExists "$INSTDIR\Installer\${ISO_NAME}" 0 iso_2
	
	Push "$INSTDIR\Installer\${ISO_NAME}"
	Call FileSize
	Pop $0
	
	StrCpy $1 "${ISO_SIZE_BYTES}"
	IntOp $1 $1 + 0
	StrCmp $0 $1 unpack_iso 0
	
	Delete "$INSTDIR\Installer\${ISO_NAME}"
	
iso_2:
!ifdef ISO_SIZE_BYTES2
	inetc::get /WEAKSECURITY /CAPTION "Downloading game ISO file" /RESUME "" /QUESTION "" "${ISO_URL2}" "$INSTDIR\Installer\${ISO_NAME}" /END
	
	IfFileExists "$INSTDIR\Installer\${ISO_NAME}" 0 iso_3
	
	Push "$INSTDIR\Installer\${ISO_NAME}"
	Call FileSize
	Pop $0
	
	StrCpy $1 "${ISO_SIZE_BYTES2}"
	IntOp $1 $1 + 0
	StrCmp $0 $1 unpack_iso 0
	
	Delete "$INSTDIR\Installer\${ISO_NAME}"
!endif

iso_3:
!ifdef ISO_SIZE_BYTES3
	inetc::get /WEAKSECURITY /CAPTION "Downloading game ISO file" /RESUME "" /QUESTION "" "${ISO_URL3}" "$INSTDIR\Installer\${ISO_NAME}" /END
!endif
skip_download_iso:
	
	IfFileExists "$INSTDIR\Installer\${ISO_NAME}" 0 iso_not_found
	
	Push "$INSTDIR\Installer\${ISO_NAME}"
	Call FileSizeIso
	Pop $0
	
	StrCmp $0 "0" iso_wrong_size 0

unpack_iso:
	DetailPrint 'Unpacking game ISO...'
	StrCmp "${GAME}" "ut2004" unpack_2004 0
	nsExec::ExecToLog '"$INSTDIR\Installer\tools\7z.exe" x -aoa -o"$INSTDIR" -x@"$INSTDIR\Installer\skip.txt" "$INSTDIR\Installer\${ISO_NAME}"'
	
	StrCmp "${GAME}" "ut99" 0 skip_bp4
	DetailPrint 'Unpacking Bonus Pack 4...'	
	nsExec::ExecToLog '"$INSTDIR\Installer\tools\7z.exe" x -aoa -o"$INSTDIR" "$INSTDIR\Installer\utbonuspack4-zip.7z"'
	Goto skip_bp4
	
unpack_2004:
	nsExec::ExecToLog '"$INSTDIR\Installer\tools\7z.exe" e -aoa -o"$INSTDIR\Installer\cabs" -ir!*.cab -ir!*.hdr "$INSTDIR\Installer\${ISO_NAME}"'
	
	${StrRep} $0 $INSTDIR "\\" "/"
	ExecWait '"$INSTDIR\Installer\tools\unshield.exe" -d "$INSTDIR\Installer\data" x "$0/Installer/cabs/data1.cab"' ; nsExec::ExecToLog kill insstaller
	
	RMDir /r "$INSTDIR\Installer\cabs"
	
	Push "$INSTDIR\Animations"		; new dest
	Push "$INSTDIR\Installer\data\All_Animations"		; new source
	Call MoveDir
	
	Push "$INSTDIR\Benchmark"		; new dest
	Push "$INSTDIR\Installer\data\All_Benchmark"		; new source
	Call MoveDir
	
	Push "$INSTDIR\ForceFeedback"		; new dest
	Push "$INSTDIR\Installer\data\All_ForceFeedback"		; new source
	Call MoveDir
	
	Push "$INSTDIR\Help"		; new dest
	Push "$INSTDIR\Installer\data\All_Help"		; new source
	Call MoveDir
	
	Push "$INSTDIR\KarmaData"		; new dest
	Push "$INSTDIR\Installer\data\All_KarmaData"		; new source
	Call MoveDir
	
	Push "$INSTDIR\Maps"		; new dest
	Push "$INSTDIR\Installer\data\All_Maps"		; new source
	Call MoveDir
	
	Push "$INSTDIR\Music"		; new dest
	Push "$INSTDIR\Installer\data\All_Music"		; new source
	Call MoveDir
	
	Push "$INSTDIR\StaticMeshes"		; new dest
	Push "$INSTDIR\Installer\data\All_StaticMeshes"		; new source
	Call MoveDir
	
	Push "$INSTDIR\Textures"		; new dest
	Push "$INSTDIR\Installer\data\All_Textures"		; new source
	Call MoveDir
	
	Push "$INSTDIR\System"		; new dest
	Push "$INSTDIR\Installer\data\All_UT2004.EXE"		; new source
	Call MoveDir
	
	Push "$INSTDIR\Web"		; new dest
	Push "$INSTDIR\Installer\data\All_Web"		; new source
	Call MoveDir
	
	Push "$INSTDIR\Manual"		; new dest
	Push "$INSTDIR\Installer\data\English_Manual"		; new source
	Call MoveDir
	
	Push "$INSTDIR"		; new dest
	Push "$INSTDIR\Installer\data\English_Sounds_Speech_System_Help"		; new source
	Call MoveDir
	
	Push "$INSTDIR\System"		; new dest
	Push "$INSTDIR\Installer\data\US_License.int"		; new source
	Call MoveDir
	
	RMDir /r "$INSTDIR\Installer\data"
	
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
	
	nsExec::ExecToLog '"$INSTDIR\Installer\tools\uz.exe" decompress "$INSTDIR\Maps\*.uz"'
	
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
	Call SaveNewDirsToRegistry

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

	WriteRegStr HKCR "${PROTOCOL}" "" "URL:${PROTOCOL} Protocol"
	WriteRegStr HKCR "${PROTOCOL}" "URL Protocol" ""
	WriteRegStr HKCR "${PROTOCOL}\shell\open\command" "" '"$INSTDIR\System\${GAME_EXE}" "%1"'
skip_protocol_handler:

	StrCmp $UmodHandler "" skip_umod_handler

	WriteRegStr HKCR ".${UMOD}" "" "${GAME}.${UMOD}File"
	WriteRegStr HKCR "${GAME}.${UMOD}File" "" "${UMOD} File"
	WriteRegStr HKCR "${GAME}.${UMOD}File\DefaultIcon" "" "$INSTDIR\System\Setup.exe,0"
	WriteRegStr HKCR "${GAME}.${UMOD}File\shell\open\command" "" '"$INSTDIR\System\Setup.exe" "%1"'
skip_umod_handler:

SectionEnd

;----------------------------------------------------------------
; Function: MoveDir
; Stack In: destFolder, sourceFolder
;   Pop $0 = sourceFolder
;   Pop $1 = destFolder
;----------------------------------------------------------------
Function MoveDir
	;— Pop args: sourceFolder → $0, destFolder → $1 —
	Exch $0
	Exch
	Exch $1
	Push $2
	Push $3

	;— Ensure destination exists —
	CreateDirectory "$1"

	;— Enumerate source —
	FindFirst $2 $3 "$0\*"
	IfErrors .Done 0

.loop:
	;— Skip “.” and “..” —
	StrCmp $3 "" .Done 0
	StrCmp $3 "." .Next 0
	StrCmp $3 ".." .Next 0

	StrCpy $4 "$0\$3"		; sourceItem
	StrCpy $5 "$1\$3"		; destItem

	;— Directory? —
	IfFileExists "$4\*.*" .IsDir 0

	; —— File branch —— 
	; If dest exists, delete it first
	IfFileExists "$5" 0 +2
		Delete "$5"
	Rename "$4" "$5"
	Goto .Next

	; —— Directory branch —— 
	.IsDir:
		Push "$5"		; new dest
		Push "$4"		; new source
		Call MoveDir

	;— Next entry —
	.Next:
		FindNext $2 $3
		IfErrors 0 .loop

	;— Cleanup —
	.Done:
		FindClose $2
	
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

Function FileSize
 
	Exch $0
	Push $1
	FileOpen $1 $0 "r"
	FileSeek $1 0 END $0
	FileClose $1
	Pop $1
	DetailPrint "File size: $0"
	Exch $0
 
FunctionEnd

Function FileSizeIso
 
	Call FileSize
	Exch $0
	Push $1
	
	DetailPrint "ISO file size: $0"
	
	StrCpy $1 "${ISO_SIZE_BYTES}"
	IntOp $1 $1 + 0
	StrCmp $0 $1 FileSizeIso_return 0
	!ifdef ISO_SIZE_BYTES2
		StrCpy $1 "${ISO_SIZE_BYTES2}"
		IntOp $1 $1 + 0
		StrCmp $0 $1 FileSizeIso_return 0
	!endif
	!ifdef ISO_SIZE_BYTES3
		StrCpy $1 "${ISO_SIZE_BYTES3}"
		IntOp $1 $1 + 0
		StrCmp $0 $1 FileSizeIso_return 0
	!endif
	StrCpy $0 "0"
FileSizeIso_return:

	Pop $1
	Exch $0
 
FunctionEnd

;--------------------------------
; Helper Function: Snapshot Existing Directories
;--------------------------------
; Scans the target directory BEFORE installation.
; Stores existing folder names in $PreInstallDirList (Format: |Dir1|Dir2|)
Function SnapshotExistingDirs
	StrCpy $PreInstallDirList "|"

	; Check if the directory exists at all. If not, the list remains just "|"
	IfFileExists "$INSTDIR\*.*" 0 done_snapshot

	Push $R0 ; Search handle
	Push $R1 ; File/Folder name

	FindFirst $R0 $R1 "$INSTDIR\*.*"

	loop_snapshot:
		StrCmp $R1 "" done_snapshot
		
		; Skip current and parent directory markers
		StrCmp $R1 "." next_snapshot
		StrCmp $R1 ".." next_snapshot

		; Check if found item is a directory
		IfFileExists "$INSTDIR\$R1\*.*" is_dir next_snapshot

		is_dir:
			; Append folder name with pipes: |FolderName|
			StrCpy $PreInstallDirList "$PreInstallDirList$R1|"
			Goto next_snapshot

		next_snapshot:
			FindNext $R0 $R1
			Goto loop_snapshot

	done_snapshot:
	FindClose $R0
	Pop $R1
	Pop $R0
FunctionEnd

;--------------------------------
; Helper Function: Calculate Diff and Save to Registry
;--------------------------------
; Scans directory AFTER installation.
; If a folder is NOT in $PreInstallDirList, it is new.
; Saves the list of NEW folders to Registry.
Function SaveNewDirsToRegistry
	StrCpy $NewDirsList ""
	
	Push $R0 ; Search handle
	Push $R1 ; File/Folder name
	Push $R2 ; Temp result

	FindFirst $R0 $R1 "$INSTDIR\*.*"

	loop_scan:
		StrCmp $R1 "" done_scan
		
		StrCmp $R1 "." next_scan
		StrCmp $R1 ".." next_scan

		IfFileExists "$INSTDIR\$R1\*.*" check_if_new next_scan

		check_if_new:
			; Search for "|FolderName|" in the PreInstallDirList
			${StrStr} $R2 "$PreInstallDirList" "|$R1|"

			; If $R2 is empty, the folder was NOT there before. It is ours.
			StrCmp $R2 "" add_to_list next_scan

			add_to_list:
				; Add to new list. Format: FolderName|
				StrCpy $NewDirsList "$NewDirsList$R1|"
				Goto next_scan

		next_scan:
			FindNext $R0 $R1
			Goto loop_scan

	done_scan:
	FindClose $R0

	; Write the final list to Registry
	; Example content: "Data|Bin|Mods|"
	WriteINIStr "${UNINST_INI}" "Uninstall" "NewDirList" "$NewDirsList"

	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; The uninstaller section
Section Uninstall
	; Ask for confirmation before proceeding
	MessageBox MB_YESNO|MB_ICONQUESTION "Are you sure you want to completely remove ${GAME_NAME}?$\r$\n$\r$\nAll files and registry entries will be removed.$\r$\n$\r$\nThis includes all content in the game folder, including custom files such as maps, textures, mods, mutators, save games, demo files, etc." IDYES remove
	
	DetailPrint "User canceled the uninstallation process."
	Abort "User canceled the uninstallation process."

remove:
	ReadINIStr $0 "${UNINST_INI}" "Uninstall" "DesktopLinks"
	StrCmp $0 "" +3 0
	Delete "$DESKTOP\${GAME_NAME_SHORT}.lnk"
	Delete "$DESKTOP\UnrealEd.lnk"

	ReadINIStr $0 "${UNINST_INI}" "Uninstall" "StartMenuLinks"
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
	
	ReadRegStr $0 HKCR "${GAME}.${UMOD}File\shell\open\command" ""
	StrCmp $0 '"$INSTDIR\System\${GAME_EXE}" "%1"' 0 skip_unreg_umod
	DeleteRegKey HKCR "${GAME}.${UMOD}File"
	
	ReadRegStr $0 HKCR ".${UMOD}" ""
	StrCmp $0 '${GAME}.${UMOD}File' 0 +2
	DeleteRegValue HKCR ".${UMOD}" ""
skip_unreg_umod:
	; 2. Read the list of folders we created from Registry
	ReadINIStr $R0 "${UNINST_INI}" "Uninstall" "NewDirList"
	
	; Verify string is not empty
	StrLen $R1 $R0
	IntCmp $R1 0 done_delete

	; 3. Parse the string and delete folders one by one
	; $R0 contains "Data|Bin|Levels|"
	StrCpy $R1 1 ; Word counter
	
	loop_delete:
		; Extract the Nth word separated by |
		${WordFind} "$R0" "|" "E+$R1" $R2
		
		; If error, no more words found
		IfErrors done_delete
		
		; Safe recursive delete of OUR folder
		DetailPrint "Removing game folder: $INSTDIR\$R2"
		RMDir /r "$INSTDIR\$R2"
		
		IntOp $R1 $R1 + 1
		Goto loop_delete

	done_delete:
	
	; 1. Delete root files explicitly
	; We must know these filenames or use a mask like *.dll, *.exe
	Delete "$INSTDIR\LICENSE.md"
	Delete "$INSTDIR\ReleaseNotes.md"
	Delete "$INSTDIR\${GAME_NAME_SHORT}.lnk"
	Delete "$INSTDIR\UnrealEd.lnk"
	Delete "${UNINST_INI}"
	Delete "${UNINST_EXE}"

	; 4. Final Cleanup
	; Attempt to remove the install root.
	; WITHOUT /r flag.
	; If user added 'Mods' or 'Screenshots', or if installed in 'C:\Games', 
	; this command will fail safely and leave the folder alone.
	RMDir "$INSTDIR"
	
	; Remove registry entries for the uninstaller registration
	DeleteRegKey HKLM "${UNINSTALLER_KEY}"
SectionEnd

!macroend