@echo off
rem Abre o Jogo Espirita direto, sem o editor do Godot.
rem Se o Godot mudar de pasta, ajuste o caminho abaixo.
set GODOT="E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
start "" %GODOT% --path "%~dp0."
