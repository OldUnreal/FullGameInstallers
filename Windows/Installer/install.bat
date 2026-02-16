@echo off
pushd "%~dp0"
.\tools\php\php.exe install.php %* && cd .. && start "" "." || pause