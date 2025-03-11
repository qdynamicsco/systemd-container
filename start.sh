#!/bin/bash
set -e

# Create log directory
mkdir -p /var/log/container

# Simpler logging approach that doesn't require /dev/fd
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/container/startup.log
}

log "Starting container..."

# Start SSH server
log "Starting SSH server..."
mkdir -p /run/sshd
/usr/sbin/sshd

# Set Wayland runtime directory
export XDG_RUNTIME_DIR=/tmp/weston
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

# Log system info for diagnosis
log "System information:"
log "Kernel: $(uname -a)"
log "Available DRM devices:"
ls -la /dev/dri/ 2>/dev/null || log "No DRM devices found"
log "Framebuffer devices:"
ls -la /dev/fb* 2>/dev/null || log "No framebuffer devices found"

# Function to start Weston with different backends
start_weston() {
    local backend="$1"
    log "Attempting to start Weston with $backend backend..."
    
    if [ "$backend" = "drm" ]; then
        weston --backend=drm-backend.so --tty=1 --use-pixman=true --log=/var/log/container/weston.log &
    elif [ "$backend" = "fbdev" ]; then
        weston --backend=fbdev-backend.so --tty=1 --use-pixman=true --log=/var/log/container/weston.log &
    elif [ "$backend" = "pixman" ]; then
        weston --backend=wayland-backend.so --use-pixman=true --log=/var/log/container/weston.log &
    else
        return 1
    fi
    
    return $?
}

# Try different backends in order of preference
for backend in drm fbdev pixman; do
    start_weston "$backend"
    WESTON_PID=$!
    
    # Wait for Weston to initialize
    log "Waiting for Weston to initialize..."
    sleep 5
    
    # Check if Weston is running
    if kill -0 $WESTON_PID 2>/dev/null; then
        log "Weston is running with $backend backend, PID $WESTON_PID"
        WESTON_STARTED=true
        break
    else
        log "Weston failed to start with $backend backend, trying next..."
    fi
done

if [ "$WESTON_STARTED" = "true" ]; then
    # Export Wayland display
    export WAYLAND_DISPLAY=wayland-0
    
    # Start Chromium with expanded parameters and logging
    log "Starting Chromium..."
    chromium-browser \
        --ozone-platform=wayland \
        --no-sandbox \
        --disable-gpu-sandbox \
        --ignore-gpu-blocklist \
        --enable-gpu-rasterization \
        --disable-dev-shm-usage \
        --disable-software-rasterizer \
        --disable-gpu-watchdog \
        --autoplay-policy=no-user-gesture-required \
        --disable-features=UserAgentClientHint \
        --kiosk \
        "about:blank" \
        > /var/log/container/chromium.log 2>&1 &
    CHROMIUM_PID=$!
    
    # Check if Chromium started successfully
    sleep 3
    if kill -0 $CHROMIUM_PID 2>/dev/null; then
        log "Chromium started successfully with PID $CHROMIUM_PID"
    else
        log "ERROR: Chromium failed to start"
        log "Chromium log output:"
        cat /var/log/container/chromium.log | tee -a /var/log/container/startup.log
    fi
else
    log "ERROR: All Weston backends failed to start"
    log "Weston log output:"
    cat /var/log/container/weston.log | tee -a /var/log/container/startup.log
fi

log "Container processes ready, running continuously to maintain SSH access"

# Function to handle termination
cleanup() {
    log "Stopping services..."
    if [[ -n "$CHROMIUM_PID" ]]; then
        kill $CHROMIUM_PID 2>/dev/null || true
    fi
    if [[ -n "$WESTON_PID" ]]; then
        kill $WESTON_PID 2>/dev/null || true
    fi
    /usr/sbin/service ssh stop
    log "Shutdown complete"
    exit
}

# Trap SIGINT and SIGTERM to gracefully shutdown
trap cleanup SIGINT SIGTERM

# Keep container running to maintain SSH access for debugging
while true; do
    sleep 60
    # Check if services are still running
    if [[ -n "$WESTON_PID" ]] && ! kill -0 $WESTON_PID 2>/dev/null; then
        log "WARNING: Weston process is no longer running"
    fi
    
    if [[ -n "$CHROMIUM_PID" ]] && ! kill -0 $CHROMIUM_PID 2>/dev/null; then
        log "WARNING: Chromium process is no longer running"
    fi
done