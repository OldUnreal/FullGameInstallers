# NSIS Script for Unreal Gold Installation

!define GAME_NAME "Unreal Gold"
!define GAME_NAME_SHORT "${GAME_NAME}"
!define GAME "ugold"
!define GAME_EXE "Unreal.exe"
!define ISO_NAME "UNREAL_GOLD.iso"
!define ISO_URL "https://archive.org/download/totallyunreal/UNREAL_GOLD.ISO"
!define ISO_SIZE_BYTES 676734976
!define NOTICE_FILE "UNOTICE.txt"
!define ADD_SIZE_BYTES 1468006

OutFile "Unreal_Gold.exe"
InstallDir "C:\Unreal"

!include "Common.nsh"

!insertmacro COMMON_INSTALLER
