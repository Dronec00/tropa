#!/usr/bin/env bash
# Запуск игры из терминала: ./run.sh
set -e
cd "$(dirname "$0")"
exec "${GODOT:-godot}" --path . "$@"
