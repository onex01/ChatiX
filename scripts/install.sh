#!/bin/bash

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SERVER_HOST="192.168.1.100"
SERVER_PATH="/var/www/uploads.onex01.ru/Android/APKs/ChatiX"

# Получаем последнюю версию
LATEST_VERSION=$(curl -s "https://uploads.onex01.ru/Android/APKs/ChatiX/version.json" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}❌ Failed to get latest version${NC}"
    exit 1
fi

APK_URL="https://uploads.onex01.ru/Android/APKs/ChatiX/ChatiX-$LATEST_VERSION.apk"
APK_FILE="ChatiX-$LATEST_VERSION.apk"

echo -e "${GREEN}📱 Downloading $APK_FILE...${NC}"
wget -O "$APK_FILE" "$APK_URL"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}📱 Installing on device...${NC}"
    adb install -r "$APK_FILE"
    rm "$APK_FILE"
    echo -e "${GREEN}✅ Done!${NC}"
else
    echo -e "${RED}❌ Download failed${NC}"
fi