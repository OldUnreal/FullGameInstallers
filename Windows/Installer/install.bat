@echo off
cd Installer
tools\php\php install.php %1 && cd .. && start "" "." || pause
