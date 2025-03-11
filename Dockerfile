# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install necessary packages including systemd
RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    xfce4 \
    xfce4-terminal \
    lightdm \
    chromium-browser \
    dbus-x11 \
    x11-xserver-utils \
    openssh-server \
    sudo \
    locales \
    xauth \
    xinit \
    xserver-xorg-input-all \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure systemd - minimal setup for containers
RUN systemctl set-default graphical.target && \
    systemctl mask systemd-udevd.service systemd-udevd-kernel.socket && \
    systemctl mask systemd-modules-load.service

# Create a user for autologin
RUN useradd -m kiosk -s /bin/bash && \
    echo "kiosk:kiosk" | chpasswd && \
    adduser kiosk sudo && \
    echo "kiosk ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Configure LightDM for auto-login
RUN mkdir -p /etc/lightdm/lightdm.conf.d
RUN echo "[Seat:*]" > /etc/lightdm/lightdm.conf.d/50-autologin.conf && \
    echo "autologin-user=kiosk" >> /etc/lightdm/lightdm.conf.d/50-autologin.conf && \
    echo "autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf.d/50-autologin.conf && \
    echo "user-session=xfce" >> /etc/lightdm/lightdm.conf.d/50-autologin.conf && \
    echo "greeter-session=lightdm-gtk-greeter" >> /etc/lightdm/lightdm.conf.d/50-autologin.conf && \
    echo "xserver-command=X -ac" >> /etc/lightdm/lightdm.conf.d/50-autologin.conf

# Create an autostart directory for the kiosk user
RUN mkdir -p /home/kiosk/.config/autostart/

# Create a more robust startup script for Chromium
RUN echo '#!/bin/bash' > /home/kiosk/start-chromium.sh && \
    echo '' >> /home/kiosk/start-chromium.sh && \
    echo '# Wait for X server and desktop environment to fully load' >> /home/kiosk/start-chromium.sh && \
    echo 'sleep 15' >> /home/kiosk/start-chromium.sh && \
    echo '' >> /home/kiosk/start-chromium.sh && \
    echo '# Kill any existing Chromium processes' >> /home/kiosk/start-chromium.sh && \
    echo 'pkill chromium || true' >> /home/kiosk/start-chromium.sh && \
    echo '' >> /home/kiosk/start-chromium.sh && \
    echo '# Launch Chromium in kiosk mode' >> /home/kiosk/start-chromium.sh && \
    echo 'export DISPLAY=:0' >> /home/kiosk/start-chromium.sh && \
    echo 'chromium-browser --no-sandbox --disable-session-crashed-bubble --disable-infobars --kiosk --start-fullscreen https://www.example.com' >> /home/kiosk/start-chromium.sh && \
    chmod +x /home/kiosk/start-chromium.sh

# Add script to autostart through multiple methods
RUN echo '[Desktop Entry]' > /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Type=Application' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Exec=/home/kiosk/start-chromium.sh' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Hidden=false' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Terminal=false' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'StartupNotify=false' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'X-GNOME-Autostart-enabled=true' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Name=Chromium Kiosk' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Comment=Start Chromium in kiosk mode' >> /home/kiosk/.config/autostart/chromium.desktop

# Add script to .xprofile to ensure it runs when X starts
RUN echo '#!/bin/bash' > /home/kiosk/.xprofile && \
    echo '/home/kiosk/start-chromium.sh &' >> /home/kiosk/.xprofile && \
    chmod +x /home/kiosk/.xprofile

# Configure Xfce to disable screen saver and power management
RUN mkdir -p /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml
RUN echo '<?xml version="1.0" encoding="UTF-8"?>' > /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '<channel name="xfce4-power-manager" version="1.0">' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '  <property name="xfce4-power-manager" type="empty">' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="dpms-enabled" type="bool" value="false"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="blank-on-ac" type="int" value="0"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="presentation-mode" type="bool" value="true"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '  </property>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '</channel>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml

# Create a systemd service that starts after X is running
RUN echo '[Unit]' > /etc/systemd/system/chromium-kiosk.service && \
    echo 'Description=Chromium Kiosk Mode' >> /etc/systemd/system/chromium-kiosk.service && \
    echo 'After=lightdm.service' >> /etc/systemd/system/chromium-kiosk.service && \
    echo '' >> /etc/systemd/system/chromium-kiosk.service && \
    echo '[Service]' >> /etc/systemd/system/chromium-kiosk.service && \
    echo 'User=kiosk' >> /etc/systemd/system/chromium-kiosk.service && \
    echo 'Environment=DISPLAY=:0' >> /etc/systemd/system/chromium-kiosk.service && \
    echo 'ExecStartPre=/bin/sleep 20' >> /etc/systemd/system/chromium-kiosk.service && \
    echo 'ExecStart=/home/kiosk/start-chromium.sh' >> /etc/systemd/system/chromium-kiosk.service && \
    echo 'Restart=on-failure' >> /etc/systemd/system/chromium-kiosk.service && \
    echo 'RestartSec=10' >> /etc/systemd/system/chromium-kiosk.service && \
    echo '' >> /etc/systemd/system/chromium-kiosk.service && \
    echo '[Install]' >> /etc/systemd/system/chromium-kiosk.service && \
    echo 'WantedBy=graphical.target' >> /etc/systemd/system/chromium-kiosk.service

# Enable the systemd service
RUN systemctl enable chromium-kiosk.service
RUN systemctl enable lightdm.service

# Create .xinitrc as another fallback
RUN echo '#!/bin/sh' > /home/kiosk/.xinitrc && \
    echo 'exec startxfce4' >> /home/kiosk/.xinitrc && \
    chmod +x /home/kiosk/.xinitrc

# Ensure proper permissions
RUN chown -R kiosk:kiosk /home/kiosk/

# Set the stop signal and command
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]