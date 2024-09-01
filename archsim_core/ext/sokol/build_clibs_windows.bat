@REM @echo off

@REM set sources=log app

@REM @REM REM D3D11 Debug
@REM @REM for %%s in (%sources%) do (
@REM @REM     cl /c /D_DEBUG /DIMPL /DSOKOL_D3D11 c\sokol_%%s.c /Z7
@REM @REM     lib /OUT:%%s\sokol_%%s_windows_x64_d3d11_debug.lib sokol_%%s.obj
@REM @REM     del sokol_%%s.obj
@REM @REM )

@REM @REM REM D3D11 Release
@REM @REM for %%s in (%sources%) do (
@REM @REM     cl /c /O2 /DNDEBUG /DIMPL /DSOKOL_D3D11 c\sokol_%%s.c
@REM @REM     lib /OUT:%%s\sokol_%%s_windows_x64_d3d11_release.lib sokol_%%s.obj
@REM @REM     del sokol_%%s.obj
@REM @REM )

@REM @REM REM GL Debug
@REM @REM for %%s in (%sources%) do (
@REM @REM     cl /c /D_DEBUG /DIMPL /DSOKOL_GLCORE c\sokol_%%s.c /Z7
@REM @REM     lib /OUT:%%s\sokol_%%s_windows_x64_gl_debug.lib sokol_%%s.obj
@REM @REM     del sokol_%%s.obj
@REM @REM )

@REM REM GL Release
@REM for %%s in (%sources%) do (
@REM     cl /c /O2 /DNDEBUG /DIMPL /DSOKOL_GLCORE c\sokol_%%s.c
@REM     lib /OUT:%%s\sokol_%%s_windows_x64_gl_release.lib sokol_%%s.obj
@REM     del sokol_%%s.obj
@REM )

@REM @REM REM D3D11 Debug DLL
@REM @REM cl /D_DEBUG /DIMPL /DSOKOL_DLL /DSOKOL_D3D11 c\sokol.c /Z7 /LDd /MDd /DLL /Fe:sokol_dll_windows_x64_d3d11_debug.dll /link /INCREMENTAL:NO

@REM @REM REM D3D11 Release DLL
@REM @REM cl /D_DEBUG /DIMPL /DSOKOL_DLL /DSOKOL_D3D11 c\sokol.c /LD /MD /DLL /Fe:sokol_dll_windows_x64_d3d11_release.dll /link /INCREMENTAL:NO

@REM @REM REM GL Debug DLL
@REM @REM cl /D_DEBUG /DIMPL /DSOKOL_DLL /DSOKOL_GLCORE c\sokol.c /Z7 /LDd /MDd /DLL /Fe:sokol_dll_windows_x64_gl_debug.dll /link /INCREMENTAL:NO

@REM REM GL Release DLL
@REM cl /D_DEBUG /DIMPL /DSOKOL_DLL /DSOKOL_GLCORE c\sokol.c /LD /MD /DLL /Fe:sokol_dll_windows_x64_gl_release.dll /link /INCREMENTAL:NO

@REM del sokol.obj

@echo off
setlocal

set SOURCES= c\sokol_app.c
set DEFINES= /DSOKOL_IMPL /DSOKOL_GLCORE

cl /c /EHsc /O2 %DEFINES% %SOURCES%
lib sokol_app.obj /OUT:sokol.lib
del *obj
