#!/bin/bash
set -e

# Enable logging
exec > /var/log/container.log 2>&1

echo "Starting container..."

# Set Wayland runtime directory
export XDG_RUNTIME_DIR=/tmp/weston
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

# Start Weston Wayland compositor in the background
echo "Starting Weston..."
weston --backend=drm-backend.so --tty=1 --use-pixman=false &
WESTON_PID=$!

# Wait for Weston to initialize
sleep 5

# Export Wayland display
export WAYLAND_DISPLAY=wayland-0

# Start Chromium with Wayland backend
echo "Starting Chromium..."
chromium --ozone-platform=wayland --no-sandbox &
CHROMIUM_PID=$!

# Function to handle termination
cleanup() {
    echo "Stopping Chromium and Weston..."
    kill $CHROMIUM_PID
    kill $WESTON_PID
    exit
}

# Trap SIGINT and SIGTERM to gracefully shutdown
trap cleanup SIGINT SIGTERM

# Wait for Weston and Chromium to exit
wait $WESTON_PID $CHROMIUM_PID