#!/bin/bash
# Создаёт на рабочем столе «Тропа.app» — двойной щелчок запускает игру.
set -e

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
APP="$HOME/Desktop/Тропа.app"

if [ ! -x "$GODOT" ]; then
	echo "Не найден Godot: $GODOT"
	echo "Укажи путь: GODOT_BIN=/путь/к/Godot $0"
	exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Тропа</string>
	<key>CFBundleDisplayName</key>
	<string>Тропа</string>
	<key>CFBundleIdentifier</key>
	<string>local.tropa.game</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleExecutable</key>
	<string>tropa</string>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

cat > "$APP/Contents/MacOS/tropa" <<LAUNCH
#!/bin/bash
GODOT="$GODOT"
PROJECT="$PROJECT"

# Важно: не запускать из папки проекта — Godot иначе подхватывает не ту сцену.
cd "\$HOME" || exit 1
exec "\$GODOT" --path "\$PROJECT" res://scenes/menu.tscn --resolution 1600x900 --position 80,60
LAUNCH

chmod +x "$APP/Contents/MacOS/tropa"
touch "$APP"
echo "Готово: $APP"
