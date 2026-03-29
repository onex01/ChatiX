#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация сервера
SERVER_USER="root"
SERVER_PASS="dfkj04251"
SERVER_HOST="onex01.ru"
SERVER_PORT="22"
SERVER_PATH="/var/www/uploads/Android/APKs/ChatiX"
UPLOAD_URL="https://uploads.onex01.ru/Android/APKs/ChatiX"

# Пути
PROJECT_DIR="/home/one/ChatiX/ChatiX"
BACKUP_DIR="$PROJECT_DIR/.backup"

cd $PROJECT_DIR

echo -e "${GREEN}🚀 Starting build process...${NC}"
echo -e "${BLUE}📡 Server: $SERVER_HOST${NC}"

# Проверяем наличие sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${YELLOW}📦 Installing sshpass...${NC}"
    sudo apt-get install -y sshpass
fi

# Создаем бэкап директорию
mkdir -p $BACKUP_DIR

# Сохраняем текущую версию
CURRENT_VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //g' | tr -d ' ')
echo -e "${YELLOW}📦 Current version: $CURRENT_VERSION"

# Разбираем версию
IFS='+' read -r VERSION_NUMBER BUILD_NUMBER <<< "$CURRENT_VERSION"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION_NUMBER"

# Рассчитываем новую версию
NEW_PATCH=$((PATCH + 1))
NEW_VERSION_NUMBER="$MAJOR.$MINOR.$NEW_PATCH"
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="$NEW_VERSION_NUMBER+$NEW_BUILD_NUMBER"

echo -e "${BLUE}🔧 Next version: $NEW_VERSION${NC}"

# Бэкапим файлы
cp pubspec.yaml "$BACKUP_DIR/pubspec.yaml.backup"
if [ -f lib/version.dart ]; then
    cp lib/version.dart "$BACKUP_DIR/version.dart.backup"
fi

# Обновляем pubspec.yaml
sed -i "s/version: $CURRENT_VERSION/version: $NEW_VERSION/" pubspec.yaml

# Обновляем version.dart
cat > lib/version.dart << EOF
// Auto-generated version file
class AppVersion {
  static const String version = '$NEW_VERSION_NUMBER';
  static const int buildNumber = $NEW_BUILD_NUMBER;
  static const String fullVersion = '$NEW_VERSION';
}
EOF

# Собираем APK
echo -e "${GREEN}📱 Building APK...${NC}"
flutter clean
flutter pub get
flutter build apk --release

# Проверяем результат сборки
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed! Rolling back version...${NC}"
    
    # Восстанавливаем бэкапы
    if [ -f "$BACKUP_DIR/pubspec.yaml.backup" ]; then
        cp "$BACKUP_DIR/pubspec.yaml.backup" pubspec.yaml
    fi
    if [ -f "$BACKUP_DIR/version.dart.backup" ]; then
        cp "$BACKUP_DIR/version.dart.backup" lib/version.dart
    fi
    
    rm -rf $BACKUP_DIR
    echo -e "${RED}🔄 Version rolled back to: $CURRENT_VERSION${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful! Version: $NEW_VERSION${NC}"

# Переименовываем APK
APK_NAME="ChatiX-$NEW_VERSION_NUMBER.apk"
cp build/app/outputs/flutter-apk/app-release.apk "build/app/outputs/flutter-apk/$APK_NAME"
echo -e "${GREEN}📦 APK created: $APK_NAME${NC}"
echo -e "${BLUE}📏 Size: $(du -h build/app/outputs/flutter-apk/$APK_NAME | cut -f1)${NC}"

# Создаем файл с информацией о версии
cat > build/app/outputs/flutter-apk/version.json << EOF
{
  "version": "$NEW_VERSION_NUMBER",
  "buildNumber": $NEW_BUILD_NUMBER,
  "downloadUrl": "$UPLOAD_URL/$APK_NAME",
  "releaseDate": "$(date -Iseconds)",
  "fileSize": "$(du -b build/app/outputs/flutter-apk/$APK_NAME | cut -f1)"
}
EOF

# Функции для работы с сервером
run_ssh() {
    sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" -p "$SERVER_PORT" "$1"
}

copy_to_server() {
    sshpass -p "$SERVER_PASS" scp -o StrictHostKeyChecking=no -P "$SERVER_PORT" "$1" "$SERVER_USER@$SERVER_HOST:$2"
}

# Загружаем на сервер
echo -e "${BLUE}📁 Creating directory on server...${NC}"
run_ssh "mkdir -p $SERVER_PATH"

echo -e "${GREEN}📤 Uploading APK to server...${NC}"
copy_to_server "build/app/outputs/flutter-apk/$APK_NAME" "$SERVER_PATH/"

echo -e "${GREEN}📤 Uploading version info...${NC}"
copy_to_server "build/app/outputs/flutter-apk/version.json" "$SERVER_PATH/"

echo -e "${BLUE}🗑️ Cleaning old versions on server...${NC}"
run_ssh "cd $SERVER_PATH && ls -t ChatiX-*.apk 2>/dev/null | tail -n +6 | xargs -r rm"

QR_URL="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$UPLOAD_URL/$APK_NAME"

echo -e ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ BUILD AND UPLOAD COMPLETE!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e ""
echo -e "${YELLOW}📱 APK URL: ${GREEN}$UPLOAD_URL/$APK_NAME${NC}"
echo -e "${YELLOW}📋 Version info: ${GREEN}$UPLOAD_URL/version.json${NC}"
echo -e "${YELLOW}📊 Version: ${GREEN}$NEW_VERSION_NUMBER (build $NEW_BUILD_NUMBER)${NC}"
echo -e ""
echo -e "${YELLOW}📱 Install on device:${NC}"
echo -e "  ${BLUE}wget $UPLOAD_URL/$APK_NAME && adb install -r $APK_NAME${NC}"
echo -e "  or scan QR code: $QR_URL"
echo -e ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"

# Очищаем бэкапы
rm -rf $BACKUP_DIR