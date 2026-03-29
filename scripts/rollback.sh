#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="/home/one/ChatiX/ChatiX"
BACKUP_DIR="$PROJECT_DIR/.backup"

cd $PROJECT_DIR

if [ -f "$BACKUP_DIR/pubspec.yaml.backup" ]; then
    echo -e "${YELLOW}🔄 Rolling back version...${NC}"
    cp "$BACKUP_DIR/pubspec.yaml.backup" pubspec.yaml
    
    if [ -f "$BACKUP_DIR/version.dart.backup" ]; then
        cp "$BACKUP_DIR/version.dart.backup" lib/version.dart
    fi
    
    rm -rf $BACKUP_DIR
    
    CURRENT_VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //g' | tr -d ' ')
    echo -e "${GREEN}✅ Rolled back to version: $CURRENT_VERSION${NC}"
else
    echo -e "${RED}❌ No backup found!${NC}"
fi