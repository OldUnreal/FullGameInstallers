# NSIS Script for Unreal Tournament Installation

!define GAME_NAME "Unreal Tournament GOTY"
!define GAME_NAME_SHORT "Unreal Tournament"
!define PRODUCT "UnrealTournament"
!define GAME "ut99"
!define GAME_EXE "UnrealTournament.exe"
!define ISO_NAME "UT_GOTY_CD1.iso"
!define ISO_URL "https://archive.org/download/ut-goty/UT_GOTY_CD1.iso"
!define ISO_SIZE_BYTES 649633792
!define NOTICE_FILE "NOTICE.txt"
!define ADD_SIZE_BYTES 1363148
!define BP4 1

OutFile "UT_GOTY.exe"
InstallDir "C:\UnrealTournament"

!include "Common.nsh"

!insertmacro COMMON_INSTALLER
