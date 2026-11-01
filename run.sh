#!/usr/bin/env bash
# Запуск игры и отдельных верстаков.
#
#   ./run.sh                — игра
#   ./run.sh character      — верстак персонажа (рыцарь, анимации)
#   ./run.sh enemies        — витрина врагов
#   ./run.sh -- --at -30,-46 — игра с телепортом к избе
set -e
cd "$(dirname "$0")"

MODE="${1:-world}"
case "$MODE" in
  world|"")
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
    echo "Доступно: world (по умолчанию), character, enemies"
    exit 1
    ;;
esac
