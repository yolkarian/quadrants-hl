@ECHO OFF

pushd %~dp0

if "%HAXE%" == "" set HAXE=haxe
if "%HL%" == "" set HL=hl
if "%BUILDDIR%" == "" set BUILDDIR=build
if "%GUIDESDIR%" == "" set GUIDESDIR=source
if "%DOX_TITLE%" == "" set DOX_TITLE=Quadrants Haxe API
if "%DOX_DESCRIPTION%" == "" set DOX_DESCRIPTION=Haxe/HashLink bindings for the Quadrants programming language.
if "%DOX_INCLUDE%" == "" set DOX_INCLUDE=^quadrants
if "%DOX_EXCLUDE%" == "" set DOX_EXCLUDE=quadrants\.macro
if "%DOX_WEBSITE%" == "" set DOX_WEBSITE=https://github.com/yolkarian/quadrants-hl

set XMLDIR=%BUILDDIR%\xml
set HTMLDIR=%BUILDDIR%\html

REM quadrants-dox is the HashLink-running Dox fork. On Windows use the
REM `haxelib run` (neko) fallback; the Makefile uses `hl run.hl` on Unix.
set QDOX=haxelib run quadrants-dox

if "%DOX_VERSION%" == "" (
	for /f "delims=" %%v in ('powershell -NoProfile -Command "(Get-Content ..\bindings\hashlink\haxelib.json ^| ConvertFrom-Json).version"') do set DOX_VERSION=%%v
)

if "%1" == "" goto help
if "%1" == "help" goto help
if "%1" == "xml" goto xml
if "%1" == "html" goto html
if "%1" == "clean" goto clean

echo Unknown target: %1
exit /b 1

:help
echo Quadrants documentation targets:
echo   make.bat html   Generate the unified Haxe API + Markdown guide site in %HTMLDIR%
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
%QDOX% -i "%XMLDIR%" -o "%HTMLDIR%" --title "%DOX_TITLE%" --toplevel-package quadrants -in "%DOX_INCLUDE%" -ex "%DOX_EXCLUDE%" -D description "%DOX_DESCRIPTION%" -D version "%DOX_VERSION%" -D website "%DOX_WEBSITE%" --guides "%GUIDESDIR%"
if errorlevel 1 exit /b 1
goto end

:clean
if exist "%BUILDDIR%" rmdir /s /q "%BUILDDIR%"
goto end

:end
popd