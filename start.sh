#!/bin/bash
# Create required runtime directories
mkdir -p /var/log/container/ /tmp/.X11-unix /run/sshd /run/dbus /tmp/.cache/fontconfig /tmp/chrome /tmp/xdg
chmod 1777 /tmp/.X11-unix
chmod 755 /run/dbus

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/container/startup.log
}

log "Starting container..."
log "Kiosk URL: ${KIOSK_URL}"

# Check for GPU
if [ -d "/dev/dri" ]; then
    log "GPU device detected at /dev/dri"
elif [ -d "/dev/nvidia0" ]; then
    log "NVIDIA GPU detected"
else
    log "No GPU devices detected, using software rendering"
fi

# Start dbus
log "Starting DBus daemon..."
dbus-daemon --system --fork --nopidfile

# Start SSH server
log "Starting SSH server..."
/usr/sbin/sshd -e

# System information
log "System information:"
log "Kernel: $(uname -a)"
log "Framebuffer devices:"
ls -la /dev/fb* 2>/dev/null || log "No framebuffer devices found"
log "Input devices:"
ls -la /dev/input/* 2>/dev/null || log "No input devices found"

# Pre-cache font configuration
log "Generating font cache..."
fc-cache -s -v > /dev/null 2>&1 || log "Font cache generation failed"

# Start X server with framebuffer and input options
log "Starting X server with framebuffer..."
xinit /root/.xinitrc -- /usr/bin/X :0 -ac -nocursor -s 0 -dpms \
    -allowMouseOpenFail \
    -logverbose 7 > /var/log/container/xorg.log  2>&1 &
XORG_PID=$!

# Wait for X server to initialize
log "Waiting for X server to initialize..."
sleep 5

# Check if X server is running
if kill -0 $XORG_PID 2>/dev/null; then
    log "X server is running with PID $XORG_PID"
    
    # Check for Chromium process
    sleep 5
    CHROMIUM_PID=$(pgrep -f chromium || echo "")
    
    if [ -n "$CHROMIUM_PID" ]; then
        log "Chromium is running with PID $CHROMIUM_PID"
    else
        log "WARNING: Chromium doesn't appear to be running"
        log "Attempting to start Chromium manually..."
        
        # Try starting Chromium manually with better options
        DISPLAY=:0 chromium --no-sandbox \
            --kiosk \
            --disable-translate \
            --disable-features=TranslateUI \
            --disable-pepper-flash-plugin \
            --disable-cloud-import \
            --disable-signin-promo \
            --disable-sync \
            --disable-default-apps \
            --disable-infobars \
            --disable-session-crashed-bubble \
            --disable-restore-session-state \
            --test-type \
            --ignore-certificate-errors \
            --start-maximized \
            --user-data-dir=/tmp/chrome \
            --no-first-run \
            --disable-crash-reporter \
            --disable-breakpad \
            --enable-gpu \
            --enable-hardware-overlays \
            --ignore-gpu-blocklist \
            --use-gl=egl \
            --enable-gpu-rasterization \
            "${KIOSK_URL}" > /var/log/container/chromium.log 2>&1 &
        
        sleep 3
        CHROMIUM_PID=$(pgrep -f chromium || echo "")
        
        if [ -n "$CHROMIUM_PID" ]; then
            log "Chromium started manually with PID $CHROMIUM_PID"
        else
            log "ERROR: Failed to start Chromium"
            log "Chromium log output:"
            cat /var/log/container/chromium.log | tee -a /var/log/container/startup.log
        fi
    fi
else
    log "ERROR: X server failed to start"
    log "X server log output:"
    cat /var/log/container/xorg.log | tee -a /var/log/container/startup.log
fi

# Check GPU status if Chromium is running
if [ -n "$CHROMIUM_PID" ]; then
    sleep 10
    log "Checking GPU status..."
    DISPLAY=:0 glxinfo | grep "OpenGL renderer" | tee -a /var/log/container/startup.log || log "Unable to get GPU info"
fi

log "Container processes ready, running continuously to maintain SSH access"

# Function to handle termination
cleanup() {
    log "Stopping services..."
    CHROMIUM_PID=$(pgrep -f chromium || echo "")
    if [ -n "$CHROMIUM_PID" ]; then
        kill $CHROMIUM_PID 2>/dev/null || true
    fi
    
    if [ -n "$XORG_PID" ]; then
        kill $XORG_PID 2>/dev/null || true
    fi
    
    pkill -f dbus-daemon || true
    pkill -f sshd || true
    log "Shutdown complete"
    exit
}

# Trap SIGINT and SIGTERM to gracefully shutdown
trap cleanup SIGINT SIGTERM

# Keep container running to maintain SSH access for debugging
while true; do
    sleep 60
    
    # Check if services are still running
    if [ -n "$XORG_PID" ] && ! kill -0 $XORG_PID 2>/dev/null; then
        log "WARNING: X server process is no longer running"
    fi
    
    CHROMIUM_PID=$(pgrep -f chromium || echo "")
    if [ -z "$CHROMIUM_PID" ]; then
        log "WARNING: Chromium process is no longer running"
    fi
done