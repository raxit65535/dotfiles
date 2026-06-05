#!/bin/bash

# Check if an application name was provided
if [ -z "$1" ]; then
    echo "Usage: ./uninstall_app.sh \"Application Name\""
    echo "Example: ./uninstall_app.sh \"Google Chrome\""
    exit 1
fi

APP_NAME="$1"
APP_PATH="/Applications/$APP_NAME.app"

echo "========================================"
echo "    Deep Uninstall: $APP_NAME"
echo "========================================"

# Step 1: Warn if the app doesn't exist in /Applications
if [ ! -d "$APP_PATH" ]; then
    echo "Warning: $APP_PATH not found."
    echo "We will still search for leftover library files."
else
    echo "Found application at: $APP_PATH"
fi

echo ""
read -p "Are you sure you want to completely remove $APP_NAME and all related files? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Uninstallation canceled."
    exit 0
fi

# Step 2: Kill related background processes
echo ""
echo "-> Force-killing any active background processes containing '$APP_NAME'..."
# pkill ignores case and matches the full command line
pkill -i -f "$APP_NAME" 2>/dev/null

# Step 3: Remove the main application file (requires sudo)
if [ -d "$APP_PATH" ]; then
    echo "-> Removing $APP_PATH (You may be prompted for your password)..."
    sudo rm -rf "$APP_PATH"
fi

# Step 4: Remove hidden Library directories
echo "-> Scrubbing ~/Library for leftover caches, logs, and preferences..."

# We use wildcards to catch variations (like "Google Chrome" vs "Chrome")
# 2>/dev/null suppresses errors if the folder doesn't exist
rm -rf ~/Library/Application\ Support/*"$APP_NAME"* 2>/dev/null
rm -rf ~/Library/Caches/*"$APP_NAME"* 2>/dev/null
rm -rf ~/Library/Preferences/*"$APP_NAME"* 2>/dev/null
rm -rf ~/Library/Logs/*"$APP_NAME"* 2>/dev/null
rm -rf ~/Library/Saved\ Application\ State/*"$APP_NAME"* 2>/dev/null
rm -rf ~/Library/Containers/*"$APP_NAME"* 2>/dev/null

echo ""
echo "========================================"
echo " Uninstallation complete for $APP_NAME! "
echo "========================================"
