FROM ghcr.io/qdynamicsco/systemd-container/systemd-container:main

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    neofetch \
    vulkan-tools \
    clinfo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/tsukumijima/libmali-rockchip/releases/download/v1.9-1-689dff3/libmali-valhall-g610-g13p0-x11-wayland-gbm_1.9-1_arm64.deb && \
    dpkg -i libmali-valhall-g610-g13p0-x11-wayland-gbm_1.9-1_arm64.deb

COPY qd.neofetch /var/lib/