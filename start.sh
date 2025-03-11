#!/bin/bash
set -e

# Create log directory
mkdir -p /var/log/container

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/container/startup.log
}

log "Starting container..."

# Start SSH server
log "Starting SSH server..."
mkdir -p /run/sshd
/usr/sbin/sshd

# System information
log "System information:"
log "Kernel: $(uname -a)"
log "Framebuffer devices:"
ls -la /dev/fb* 2>/dev/null || log "No framebuffer devices found"
log "Input devices:"
ls -la /dev/input/* 2>/dev/null || log "No input devices found"
log "Input device details:"
input-events --help >/dev/null 2>&1 && input-events -l || log "input-events not available"

# Set proper permissions on input devices
log "Setting permissions on input devices"
chmod 666 /dev/input/* 2>/dev/null || log "Failed to set permissions on input devices"

# Create simple .xinitrc file
cat > /root/.xinitrc << EOF
#!/bin/sh

# Start a minimal window manager
openbox &

# Start Chromium in kiosk mode
chromium --no-sandbox --kiosk "about:blank" &

# Keep the X session running
exec tail -f /dev/null
EOF

chmod +x /root/.xinitrc

# Start X server with framebuffer and input options
log "Starting X server with framebuffer..."
xinit /root/.xinitrc -- /usr/bin/X :0 -ac -nocursor -s 0 -dpms \
    -allowMouseOpenFail \
    -logverbose 7 > /var/log/container/xorg.log 2>&1 &
XORG_PID=$!

# Wait for X server to initialize
log "Waiting for X server to initialize..."
sleep 5

# Check if X server is running
if kill -0 $XORG_PID 2>/dev/null; then
    log "X server is running with PID $XORG_PID"
    
    # Check for Chromium process
    sleep 3
    CHROMIUM_PID=$(pgrep -f chromium || echo "")
    
    if [ -n "$CHROMIUM_PID" ]; then
        log "Chromium is running with PID $CHROMIUM_PID"
    else
        log "WARNING: Chromium doesn't appear to be running"
        log "Attempting to start Chromium manually..."
        
        # Try starting Chromium manually
        DISPLAY=:0 chromium --no-sandbox --kiosk "https://google.com" > /var/log/container/chromium.log 2>&1 &
        
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
    if [ -n "$XORG_PID" ] && ! kill -0 $XORG_PID 2>/dev/null; then
        log "WARNING: X server process is no longer running"
    fi
    
    CHROMIUM_PID=$(pgrep -f chromium || echo "")
    if [ -z "$CHROMIUM_PID" ]; then
        log "WARNING: Chromium process is no longer running"
    fi
done