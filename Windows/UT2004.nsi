# NSIS Script for Unreal Tournament Installation

!define GAME_NAME "Unreal Tournament 2004 ECE"
!define GAME_NAME_SHORT "UT2004"
!define PRODUCT "UT2004"
!define GAME "ut2004"
!define GAME_EXE "UT2004.exe"
!define ISO_NAME "UT2004.iso"
!define ISO_URL "https://files.oldunreal.net/UT2004.ISO"
!define ISO_URL2 "https://files.oldunreal.net/UT2004.ISO"
!define ISO_URL3 "https://archive.org/download/ut-2004/UT2004.ISO"
!define ISO_SIZE_BYTES 2995322880
!define ISO_SIZE_BYTES2 2995322880
!define ISO_SIZE_BYTES3 3751510016
!define PATCH_URL "https://api.github.com/repos/OldUnreal/UT2004Patches/releases/latest"
!define NOTICE_FILE "NOTICE2004.txt"
!define ADD_SIZE_KB 15728640
!define PROTOCOL "ut2004"
!define UMOD "ut4mod"
!define DENY_FROM_CD 1

OutFile "UT2004.exe"
InstallDir "C:\UnrealTournament2004"

!include "Common.nsh"

!insertmacro COMMON_INSTALLER
