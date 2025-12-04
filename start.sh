#!/bin/bash

# Cleanup old state (if restarted)
rm -f /tmp/.X0-lock
rm -rf /tmp/xdg

# Create required runtime directories
mkdir -p /run/sshd
mkdir -p /run/dbus
mkdir -p -m 0700 /tmp/xdg

# --- KERNEL 6.1 / PANFROST FIX ---
# This environment variable disables AFBC, a compression format that is often
# buggy between the Panfrost GPU driver and the Rockchip VOP display driver.
# It is the correct alternative to WLR_DRM_NO_MODIFIERS for an X11/Mesa stack.
export PAN_MESA_DEBUG=noafbc
# ---------------------------------

# Grant access to hardware devices for the container
chmod 666 /dev/dri/card* 2>/dev/null
chmod 666 /dev/dri/render* 2>/dev/null
# Also chmod video devices for when you fix the kernel driver later
chmod 666 /dev/video* 2>/dev/null

# Start essential services
/usr/sbin/sshd
dbus-daemon --system

echo "Starting X Server..."

# Start the X server and the Openbox session
xinit -- /usr/bin/X :0 -nocursor -s 0 -dpms

# Fallback to keep the container running if xinit exits
tail -f /dev/null