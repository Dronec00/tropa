#!/usr/bin/env bash
# Запуск игры и отдельных верстаков.
#
#   ./run.sh                — меню
#   ./run.sh world          — сразу мир (ночь)
#   ./run.sh day            — мир днём (evening/morning/night тоже)
#   ./run.sh character      — верстак персонажа (рыцарь, анимации)
#   ./run.sh enemies        — витрина врагов
#   ./run.sh -- --at -30,-46 — игра с телепортом к избе
set -e
cd "$(dirname "$0")"

MODE="${1:-world}"
case "$MODE" in
  world)
    shift || true
    exec "${GODOT:-godot}" --path . res://scenes/main.tscn "$@"
    ;;
  day|morning|evening|night)
    TIME_OF_DAY="$MODE"
    shift || true
    TROPA_TOD="$TIME_OF_DAY" exec "${GODOT:-godot}" --path . res://scenes/main.tscn "$@"
    ;;
  menu|"")
    shift || true
    exec "${GODOT:-godot}" --path . "$@"
    ;;
  character|char)
    shift || true
    exec "${GODOT:-godot}" --path . res://scenes/character_lab.tscn "$@"
    ;;
  enemies|enemy|mobs)
    shift || true
    exec "${GODOT:-godot}" --path . res://scenes/enemy_lab.tscn "$@"
    ;;
  *)
    echo "Неизвестный режим: $MODE"
    echo "Доступно: world, day, morning, evening, night, menu, character, enemies"
    exit 1
    ;;
esac
