FROM alpine:3.21

# Install required packages
RUN apk update && apk add --no-cache \
    chromium \
    xorg-server \
    xf86-video-fbdev \
    xf86-input-libinput \
    xf86-input-evdev \
    xauth \
    xinit \
    openbox \
    openssh \
    dbus \
    eudev \
    acl \
    sudo \
    libinput-tools \
    evtest \
    font-noto \
    pulseaudio \
    bash \
    tzdata

# Setup input permissions
RUN addgroup root input && \
    addgroup root video && \
    addgroup root tty

# Create udev rules for input devices
RUN mkdir -p /etc/udev/rules.d && \
    echo 'SUBSYSTEM=="input", MODE="0666"' > /etc/udev/rules.d/99-input.rules

# Setup SSH
RUN mkdir -p /root/.ssh /run/sshd && chmod 700 /root/.ssh

# Add SSH public keys
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

# Configure SSH
RUN sed -i 's/#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    ssh-keygen -A

# Create startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set the entrypoint
CMD ["/start.sh"]