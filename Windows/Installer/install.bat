@echo off
cd Installer
tools\php\php install.php %* && cd .. && start "" "." || pause
