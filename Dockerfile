# Use Debian Bookworm as base image
FROM debian:trixie

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV KIOSK_URL="https://google.com"
ENV DISPLAY=:0
ENV HOME=/root
ENV XDG_RUNTIME_DIR=/tmp/xdg

# Install necessary packages, then remove unnecessary ones
RUN apt-get update && apt-get install -y \
    chromium \
    xserver-xorg-core \
    xinit \
    openbox \
    openssh-server \
    dbus-x11 \
    udev \
    sudo \
    fonts-noto \
    mesa-utils \
    libgl1-mesa-dri \
    intel-media-va-driver \
    i965-va-driver \
    mesa-va-drivers \
    mesa-vulkan-drivers \
    vainfo \
    python3-xdg \
    unclutter \
    --no-install-recommends \
    && apt-get purge -y --auto-remove system-config-printer at-spi2-core \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Add user to necessary groups for hardware access
RUN usermod -a -G video,render,input root

# SSH Configuration
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
ADD https://github.com/danward.keys /root/.ssh/authorized_keys
ADD https://github.com/alexanderturner.keys /root/.ssh/authorized_keys_alex
RUN cat /root/.ssh/authorized_keys_alex >> /root/.ssh/authorized_keys && \
    rm /root/.ssh/authorized_keys_alex && \
    chown root:root /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Openbox Configuration for Kiosk Mode
RUN mkdir -p /root/.config/openbox
COPY autostart /root/.config/openbox/autostart
COPY rc.xml /root/.config/openbox/rc.xml

# Xinit Configuration
COPY xinitrc /root/.xinitrc
RUN chmod +x /root/.xinitrc

# Start Script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set the entrypoint
CMD ["/start.sh"]
