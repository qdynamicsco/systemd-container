# Use Ubuntu 24.04 as base image  
FROM ubuntu:24.04

# Install systemd and the dependencies that already worked plus additional packages  
RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    kmod \
    ethtool \
    ubuntu-desktop-minimal \
    iproute2 \
    openssh-server \
    sudo \
    chromium-browser \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create user "qd" for login purposes (if not already created)  
RUN useradd -m qd && \
    echo "qd:qdpassword" | chpasswd && \
    usermod -aG sudo qd && \
    chsh -s /bin/bash qd

# Set up SSH (kept as in your original file)  
RUN mkdir /var/run/sshd && \
    mkdir -p /home/qd/.ssh && \
    chown qd:qd /home/qd/.ssh && \
    chmod 700 /home/qd/.ssh

# Add SSH public keys  
ADD https://github.com/danward.keys /home/qd/.ssh/authorized_keys  
ADD https://github.com/alexanderturner.keys /home/qd/.ssh/authorized_keys_alex  
RUN cat /home/qd/.ssh/authorized_keys_alex >> /home/qd/.ssh/authorized_keys && \
    rm /home/qd/.ssh/authorized_keys_alex && \
    chown qd:qd /home/qd/.ssh/authorized_keys && \
    chmod 600 /home/qd/.ssh/authorized_keys

# Disable screen timeout and screen saver for Xfce (using your previous config sample)  
RUN mkdir -p /home/qd/.config/xfce4/xfconf/xfce-perchannel-xml && \
    echo '<?xml version="1.0" encoding="UTF-8"?>' > /home/qd/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '<channel name="xfce4-power-manager" version="1.0">' >> /home/qd/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '  <property name="locking" type="bool" value="false"/>' >> /home/qd/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '  <property name="dpms-on-ac-sleep" type="int" value="0"/>' >> /home/qd/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '  <property name="dpms-on-ac-off" type="int" value="0"/>' >> /home/qd/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '</channel>' >> /home/qd/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    chown -R qd:qd /home/qd/.config

# Configure LightDM for auto-login.
# Create a config file (here we name it 60-xfce4.conf) to use the xfce session
RUN mkdir -p /etc/lightdm/lightdm.conf.d && \
    echo "[Seat:*]" > /etc/lightdm/lightdm.conf.d/60-xfce4.conf && \
    echo "autologin-user=qd" >> /etc/lightdm/lightdm.conf.d/60-xfce4.conf && \
    echo "autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf.d/60-xfce4.conf && \
    echo "user-session=xfce" >> /etc/lightdm/lightdm.conf.d/60-xfce4.conf

# Create an autostart entry for Chromium in kiosk mode.
# This file will be read by the desktop session (Xfce) once logged in.
RUN mkdir -p /home/qd/.config/autostart && \
    echo "[Desktop Entry]" > /home/qd/.config/autostart/chromium.desktop && \
    echo "Type=Application" >> /home/qd/.config/autostart/chromium.desktop && \
    echo 'Exec=sh -c "sleep 10 && chromium-browser --no-sandbox --disable-infobars --kiosk --start-fullscreen https://www.google.com"' >> /home/qd/.config/autostart/chromium.desktop && \
    echo "Hidden=false" >> /home/qd/.config/autostart/chromium.desktop && \
    echo "Terminal=false" >> /home/qd/.config/autostart/chromium.desktop && \
    echo "X-GNOME-Autostart-enabled=true" >> /home/qd/.config/autostart/chromium.desktop && \
    echo "Name=Chromium Kiosk" >> /home/qd/.config/autostart/chromium.desktop && \
    echo "Comment=Start Chromium in kiosk mode" >> /home/qd/.config/autostart/chromium.desktop && \
    chown -R qd:qd /home/qd/.config

# (Optional) If desired, you can also add a simple script in the user's home and source it from .xprofile.
RUN echo '#!/bin/bash' > /home/qd/.xprofile && \
    echo 'sh -c "sleep 15 && chromium-browser --no-sandbox --disable-infobars --kiosk --start-fullscreen http://your-url-here" &' >> /home/qd/.xprofile && \
    chmod +x /home/qd/.xprofile && \
    chown qd:qd /home/qd/.xprofile

# Retain your original CMD with systemd as the PID 1 process
STOPSIGNAL SIGRTMIN+3  
CMD ["/lib/systemd/systemd"]