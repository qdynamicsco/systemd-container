#!/bin/bash

# Create required runtime directories
mkdir -p /run/sshd
mkdir -p /run/dbus
mkdir -p -m 0700 /tmp/xdg

# Start essential services
/usr/sbin/sshd
dbus-daemon --system

# Start the X server and the Openbox session
# -s 0: disables screensaver timeout
# -dpms: disables Display Power Management Signaling
xinit -- /usr/bin/X :0 -nocursor -s 0 -dpms

# Fallback to keep the container running if xinit exits
tail -f /dev/null