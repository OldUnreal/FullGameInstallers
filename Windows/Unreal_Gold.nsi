# NSIS Script for Unreal Gold Installation

!define GAME_NAME "Unreal Gold"
!define GAME_NAME_SHORT "${GAME_NAME}"
!define PRODUCT "Unreal Gold"
!define GAME "ugold"
!define GAME_EXE "Unreal.exe"
!define ISO_NAME "UNREAL_GOLD.iso"
!define ISO_URL "https://files.oldunreal.net/UNREAL_GOLD.ISO"
!define ISO_URL2 "https://archive.org/download/totallyunreal/UNREAL_GOLD.ISO"
!define ISO_SIZE_BYTES 676734976
!define ISO_SIZE_BYTES2 676734976
!define PATCH_URL "https://api.github.com/repos/OldUnreal/Unreal-testing/releases/tags/v227k_12"
!define NOTICE_FILE "UNOTICE.txt"
!define ADD_SIZE_KB 1468006
!define PROTOCOL "unreal"
!define UMOD "umod"

OutFile "Unreal_Gold.exe"
InstallDir "C:\Unreal"

!include "Common.nsh"

!insertmacro COMMON_INSTALLER
