@echo off
setlocal
set "ROOT=%~dp0"
if not exist "%ROOT%android\gradle\wrapper\gradle-wrapper.jar" (
  where bash >nul 2>nul
  if errorlevel 1 (
    echo Gradle Wrapper JAR is missing. Run scripts\bootstrap_gradle_wrapper.sh from Git Bash first. 1>&2
    exit /b 1
  )
  bash "%ROOT%scripts\bootstrap_gradle_wrapper.sh"
  if errorlevel 1 exit /b %ERRORLEVEL%
)
pushd "%ROOT%android"
call gradlew.bat %*
set "ERR=%ERRORLEVEL%"
popd
exit /b %ERR%
