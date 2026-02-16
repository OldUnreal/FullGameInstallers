@echo off
pushd "%~dp0"
.\tools\php\php install.php %* && cd .. && start "" "." || pause