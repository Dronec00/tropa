@echo off
rem Запуск «Тропы» без редактора. Поправь путь к Godot при необходимости.
set GODOT=%~dp0Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" set GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe

if not exist "%GODOT%" (
  echo Не найден Godot. Укажи путь к exe в переменной GODOT в этом файле.
  pause
  exit /b 1
)

start "" "%GODOT%" --path "%~dp0" res://scenes/menu.tscn
