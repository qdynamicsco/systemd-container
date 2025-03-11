# Use Debian Bookworm as base image (ARM64 compatible)
FROM debian:bookworm

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install X11 with framebuffer support, Chromium, and SSH
RUN apt-get update && apt-get install -y \
    chromium \
    xserver-xorg-core \
    xserver-xorg-video-fbdev \
    x11-xserver-utils \
    xinit \
    openbox \
    openssh-server \
    dbus \
    udev \
    fonts-noto \
    pulseaudio \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup SSH
RUN mkdir -p /root/.ssh /run/sshd && chmod 700 /root/.ssh

# Add SSH public keys for danward and alexanderturner
ADD https://github.com/danward.keys /root/.ssh/authorized_keys
ADD https://github.com/alexanderturner.keys /root/.ssh/authorized_keys_alex
RUN cat /root/.ssh/authorized_keys_alex >> /root/.ssh/authorized_keys && \
    rm /root/.ssh/authorized_keys_alex && \
    chmod 600 /root/.ssh/authorized_keys

# Create necessary directories for logging
RUN mkdir -p /var/log/container

# Create X11 configuration for framebuffer
RUN mkdir -p /etc/X11/xorg.conf.d && \
    echo 'Section "Device"\n\
    Identifier "Framebuffer"\n\
    Driver "fbdev"\n\
    Option "fbdev" "/dev/fb0"\n\
EndSection' > /etc/X11/xorg.conf.d/99-fbdev.conf

# Create startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set the entrypoint
CMD ["/start.sh"]