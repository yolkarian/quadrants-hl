@ECHO OFF

pushd %~dp0

if "%HAXE%" == "" set HAXE=haxe
if "%DOX%" == "" set DOX=haxelib run dox
if "%BUILDDIR%" == "" set BUILDDIR=build
if "%DOX_TITLE%" == "" set DOX_TITLE=Quadrants Haxe API
if "%DOX_DESCRIPTION%" == "" set DOX_DESCRIPTION=Haxe/HashLink bindings for the Quadrants programming language.
if "%DOX_INCLUDE%" == "" set DOX_INCLUDE=^quadrants
if "%DOX_EXCLUDE%" == "" set DOX_EXCLUDE=quadrants\.macro

set XMLDIR=%BUILDDIR%\xml
set HTMLDIR=%BUILDDIR%\html

if "%1" == "" goto help
if "%1" == "help" goto help
if "%1" == "xml" goto xml
if "%1" == "html" goto html
if "%1" == "clean" goto clean

echo Unknown target: %1
exit /b 1

:help
echo Quadrants documentation targets:
echo   make.bat html   Generate Haxe API docs in %HTMLDIR% with Dox
echo   make.bat xml    Generate Haxe XML docs in %XMLDIR%
echo   make.bat clean  Remove %BUILDDIR%
goto end

:xml
if not exist "%XMLDIR%" mkdir "%XMLDIR%"
%HAXE% dox.hxml
if errorlevel 1 exit /b 1
goto end

:html
if not exist "%XMLDIR%" mkdir "%XMLDIR%"
%HAXE% dox.hxml
if errorlevel 1 exit /b 1
if exist "%HTMLDIR%" rmdir /s /q "%HTMLDIR%"
%DOX% -i "%XMLDIR%" -o "%HTMLDIR%" --title "%DOX_TITLE%" --toplevel-package quadrants -in "%DOX_INCLUDE%" -ex "%DOX_EXCLUDE%" -D description "%DOX_DESCRIPTION%" %DOXOPTS%
if errorlevel 1 exit /b 1
goto end

:clean
if exist "%BUILDDIR%" rmdir /s /q "%BUILDDIR%"
goto end

:end
popd
