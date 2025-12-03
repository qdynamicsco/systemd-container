FROM ubuntu:jammy

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV KIOSK_URL="https://google.com"
ENV DISPLAY=:0
ENV HOME=/root
ENV XDG_RUNTIME_DIR=/tmp/xdg

# 1. Setup PPA
RUN apt-get update && apt-get install -y software-properties-common gpg wget curl && \
    add-apt-repository ppa:liujianfeng1994/rockchip-multimedia

# 2. Pin the PPA
# This ensures we get the "rkmpp" version of Chromium
RUN echo "Package: *\nPin: release o=LP-PPA-liujianfeng1994-rockchip-multimedia\nPin-Priority: 1001\n" > /etc/apt/preferences.d/rockchip-ppa

# 3. Install System & Rockchip Stack
# REMOVED: rockchip-multimedia-config (Fails in Docker)
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
    # --- Rockchip Specifics ---
    librockchip-mpp1 \
    librockchip-vpu0 \
    librga2 \
    gstreamer1.0-rockchip1 \
    libv4l-rkmpp \
    chromium \
    chromium-sandbox \
    libxcb-dri2-0 \
    # --------------------------
    unclutter \
    --no-install-recommends \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 4. Install LibMali Blob (RK3399 / Midgard / r18p0) for Kernel 4.19
RUN wget https://github.com/tsukumijima/libmali-rockchip/releases/download/v1.9-1-2131373/libmali-midgard-t86x-r18p0-x11-gbm_1.9-1_arm64.deb && \
    dpkg -i libmali-midgard-t86x-r18p0-x11-gbm_1.9-1_arm64.deb && \
    rm libmali-midgard-t86x-r18p0-x11-gbm_1.9-1_arm64.deb

# 5. Fix Chromium Permissions for Container
# Chromium sandbox often fails in containers without SUID fixes, 
# though running with --no-sandbox (in start.sh) is the primary fix.
RUN chown root:root /usr/lib/chromium/chrome-sandbox && \
    chmod 4755 /usr/lib/chromium/chrome-sandbox

# Add user to necessary groups
# 'video' is critical for MPP access on the host
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
COPY xorg.conf /etc/X11/xorg.conf

# Start Script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set the entrypoint
CMD ["/start.sh"]