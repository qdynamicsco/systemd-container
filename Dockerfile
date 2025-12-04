FROM ubuntu:jammy

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV KIOSK_URL="https://google.com"
# Using Wayland (Cage) is better for Panfrost than X11, but if you must use X11:
ENV DISPLAY=:0
ENV HOME=/root
ENV XDG_RUNTIME_DIR=/tmp/xdg

# 1. Setup PPA for Chromium
# We keep this PPA because it provides a Chromium build that understands V4L2
RUN apt-get update && apt-get install -y software-properties-common gpg wget curl && \
    add-apt-repository ppa:liujianfeng1994/rockchip-multimedia

# 2. Pin the PPA
RUN echo "Package: *\nPin: release o=LP-PPA-liujianfeng1994-rockchip-multimedia\nPin-Priority: 1001\n" > /etc/apt/preferences.d/rockchip-ppa

# 3. Install System & Modern Graphics Stack
RUN apt-get update && apt-get install -y \
    xserver-xorg-core \
    xinit \
    openbox \
    openssh-server \
    dbus-x11 \
    udev \
    sudo \
    fonts-noto \
    mesa-utils \
    nano \
    # --- Graphics / Multimedia ---
    mesa-vulkan-drivers \
    libgl1-mesa-dri \
    libglx-mesa0 \
    libegl-mesa0 \
    libgbm1 \
    libv4l-0 \
    # --- Rockchip Specifics ---
    # These are still useful for the V4L2 video codecs
    librockchip-mpp1 \
    librockchip-vpu0 \
    librga2 \
    gstreamer1.0-rockchip1 \
    libv4l-rkmpp \
    chromium \
    chromium-sandbox \
    # --------------------------
    unclutter \
    --no-install-recommends \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 5. Fix Chromium Permissions
RUN chown root:root /usr/lib/chromium/chrome-sandbox && \
    chmod 4755 /usr/lib/chromium/chrome-sandbox

# Add user to necessary groups
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
RUN mkdir -p /run/sshd 

# Openbox Configuration
RUN mkdir -p /root/.config/openbox
COPY autostart /root/.config/openbox/autostart
COPY rc.xml /root/.config/openbox/rc.xml

# Xinit Configuration
COPY xinitrc /root/.xinitrc
RUN chmod +x /root/.xinitrc

# Start Script
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]