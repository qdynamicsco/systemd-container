# Use Debian Bookworm as base image (ARM64 compatible)
FROM debian:bookworm

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install X11 with framebuffer support, Chromium, and SSH
RUN apt-get update && apt-get install -y \
    chromium \
    xserver-xorg-core \
    xserver-xorg-video-fbdev \
    xserver-xorg-input-libinput \
    xserver-xorg-input-evdev \
    x11-xserver-utils \
    xinit \
    openbox \
    openssh-server \
    dbus \
    udev \
    acl \
    sudo \
    input-utils \
    fonts-noto \
    pulseaudio \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup input permissions
RUN groupadd -f input && \
    usermod -a -G input,video,tty root

# Create udev rules for input devices
RUN mkdir -p /etc/udev/rules.d && \
    echo 'SUBSYSTEM=="input", MODE="0666"' > /etc/udev/rules.d/99-input.rules

# Setup SSH
RUN mkdir -p /root/.ssh /run/sshd && chmod 700 /root/.ssh

# Add SSH public keys for danward and alexanderturner
ADD https://github.com/danward.keys /root/.ssh/authorized_keys
ADD https://github.com/alexanderturner.keys /root/.ssh/authorized_keys_alex
RUN cat /root/.ssh/authorized_keys_alex >> /root/.ssh/authorized_keys && \
    rm /root/.ssh/authorized_keys_alex && \
    chown root:root /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys

# Create necessary directories for logging
RUN mkdir -p /var/log/container

# Create X11 configuration for framebuffer and input
RUN mkdir -p /etc/X11/xorg.conf.d && \
    echo 'Section "Device"\n\
    Identifier "Framebuffer"\n\
    Driver "fbdev"\n\
    Option "fbdev" "/dev/fb0"\n\
EndSection' > /etc/X11/xorg.conf.d/99-fbdev.conf && \
    echo 'Section "InputClass"\n\
    Identifier "evdev keyboard catchall"\n\
    MatchIsKeyboard "on"\n\
    MatchDevicePath "/dev/input/event*"\n\
    Driver "evdev"\n\
    Option "GrabDevice" "true"\n\
EndSection\n\
\n\
Section "InputClass"\n\
    Identifier "evdev pointer catchall"\n\
    MatchIsPointer "on"\n\
    MatchDevicePath "/dev/input/event*"\n\
    Driver "evdev"\n\
    Option "GrabDevice" "true"\n\
EndSection' > /etc/X11/xorg.conf.d/10-input.conf

# Create startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set the entrypoint
CMD ["/start.sh"]