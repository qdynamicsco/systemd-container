FROM ghcr.io/qdynamicsco/systemd-container/systemd-container:main

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    neofetch && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://repo.rock-chips.com/edge/debian-release-v2.0.0/pool/main/r/rockchip-mali/rockchip-mali_1.9-12_arm64.deb && \
    dpkg -i rockchip-mali_1.9-12_arm64.deb && \    
    ln -s /usr/lib/aarch64-linux-gnu/libmali-valhall-g610-g6p0-wayland-gbm-vulkan.so /usr/lib/aarch64-linux-gnu/libmali.so && \
    mkdir -p /etc/vulkan/icd.d/

COPY icd-mali.json /etc/vulkan/icd.d/mali.json

COPY qd.neofetch /var/lib/