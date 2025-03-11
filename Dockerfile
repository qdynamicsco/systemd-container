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
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure systemd - minimal setup for containers
RUN systemctl set-default graphical.target && \
    systemctl mask systemd-udevd.service systemd-udevd-kernel.socket && \
    systemctl mask systemd-modules-load.service && \
    systemctl mask systemd-resolved.service && \
    systemctl mask systemd-journald-audit.socket && \
    find /etc/systemd/system \
    /lib/systemd/system \
    -path '*.wants/*' \
    -not -name '*journald*' \
    -not -name '*systemd-tmpfiles*' \
    -not -name '*systemd-user-sessions*' \
    -exec rm \{} \;

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

# Create a startup script for Chromium
RUN echo '#!/bin/bash' > /home/kiosk/start-chromium.sh && \
    echo 'sleep 5' >> /home/kiosk/start-chromium.sh && \
    echo 'chromium-browser --no-sandbox --kiosk --disable-restore-session-state --disable-component-update --start-maximized --start-fullscreen https://www.google.com' >> /home/kiosk/start-chromium.sh && \
    chmod +x /home/kiosk/start-chromium.sh

# Create an autostart entry for Chromium
RUN echo '[Desktop Entry]' > /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Type=Application' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Exec=/home/kiosk/start-chromium.sh' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Hidden=false' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'NoDisplay=false' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'X-GNOME-Autostart-enabled=true' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Name=Chromium Kiosk' >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo 'Comment=Start Chromium in kiosk mode' >> /home/kiosk/.config/autostart/chromium.desktop

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

# Create a custom systemd service to handle the X session
RUN echo '[Unit]' > /etc/systemd/system/kiosk.service && \
    echo 'Description=Kiosk Mode Service' >> /etc/systemd/system/kiosk.service && \
    echo 'After=lightdm.service' >> /etc/systemd/system/kiosk.service && \
    echo '' >> /etc/systemd/system/kiosk.service && \
    echo '[Service]' >> /etc/systemd/system/kiosk.service && \
    echo 'Type=simple' >> /etc/systemd/system/kiosk.service && \
    echo 'User=kiosk' >> /etc/systemd/system/kiosk.service && \
    echo 'Environment=DISPLAY=:0' >> /etc/systemd/system/kiosk.service && \
    echo 'ExecStartPre=/bin/sleep 10' >> /etc/systemd/system/kiosk.service && \
    echo 'ExecStart=/home/kiosk/start-chromium.sh' >> /etc/systemd/system/kiosk.service && \
    echo 'Restart=on-failure' >> /etc/systemd/system/kiosk.service && \
    echo 'RestartSec=5s' >> /etc/systemd/system/kiosk.service && \
    echo '' >> /etc/systemd/system/kiosk.service && \
    echo '[Install]' >> /etc/systemd/system/kiosk.service && \
    echo 'WantedBy=graphical.target' >> /etc/systemd/system/kiosk.service

# Enable the necessary services
RUN systemctl enable lightdm.service && \
    systemctl enable kiosk.service

# Ensure proper permissions
RUN chown -R kiosk:kiosk /home/kiosk/

# This is critical for systemd to operate properly in a container
VOLUME [ "/sys/fs/cgroup" ]

# Set the stop signal and command
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]