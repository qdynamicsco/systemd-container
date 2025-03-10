# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up systemd
RUN cd /lib/systemd/system/sysinit.target.wants/ && \
    ls | grep -v systemd-tmpfiles-setup | xargs rm -f && \
    rm -f /lib/systemd/system/multi-user.target.wants/* && \
    rm -f /etc/systemd/system/*.wants/* && \
    rm -f /lib/systemd/system/local-fs.target.wants/* && \
    rm -f /lib/systemd/system/sockets.target.wants/*udev* && \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl* && \
    rm -f /lib/systemd/system/basic.target.wants/* && \
    rm -f /lib/systemd/system/anaconda.target.wants/* && \
    rm -f /lib/systemd/system/plymouth* && \
    rm -f /lib/systemd/system/systemd-update-utmp*

# Create a user for autologin
RUN useradd -m kiosk -s /bin/bash && \
    echo "kiosk:kiosk" | chpasswd && \
    adduser kiosk sudo

# Set up SSH if needed
RUN mkdir /var/run/sshd && \
    mkdir -p /home/kiosk/.ssh && \
    chown kiosk:kiosk /home/kiosk/.ssh && \
    chmod 700 /home/kiosk/.ssh

# Configure LightDM for auto-login
RUN mkdir -p /etc/lightdm/lightdm.conf.d
RUN echo "[SeatDefaults]" > /etc/lightdm/lightdm.conf.d/10-autologin.conf && \
    echo "autologin-user=kiosk" >> /etc/lightdm/lightdm.conf.d/10-autologin.conf && \
    echo "autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf.d/10-autologin.conf && \
    echo "user-session=xfce" >> /etc/lightdm/lightdm.conf.d/10-autologin.conf

# Create an autostart directory
RUN mkdir -p /home/kiosk/.config/autostart/

# Create a script to launch Chromium in fullscreen mode with the specified URL
RUN echo "[Desktop Entry]" > /home/kiosk/.config/autostart/chromium.desktop && \
    echo "Type=Application" >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo "Exec=sh -c \"sleep 5 && chromium-browser --no-sandbox --kiosk --start-fullscreen https://www.example.com\"" >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo "Hidden=false" >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo "NoDisplay=false" >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo "X-GNOME-Autostart-enabled=true" >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo "Name=Chromium Kiosk" >> /home/kiosk/.config/autostart/chromium.desktop && \
    echo "Comment=Start Chromium in kiosk mode" >> /home/kiosk/.config/autostart/chromium.desktop

# Configure Xfce to disable screen saver and power management
RUN mkdir -p /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml
RUN echo '<?xml version="1.0" encoding="UTF-8"?>' > /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '<channel name="xfce4-power-manager" version="1.0">' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '  <property name="xfce4-power-manager" type="empty">' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="dpms-enabled" type="bool" value="false"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="blank-on-ac" type="int" value="0"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="logind-handle-lid-switch" type="bool" value="false"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="show-tray-icon" type="bool" value="false"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="general-notification" type="bool" value="false"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '    <property name="presentation-mode" type="bool" value="true"/>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '  </property>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '</channel>' >> /home/kiosk/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml

# Create a service to start lightdm
RUN echo "[Unit]" > /etc/systemd/system/kiosk.service && \
    echo "Description=Kiosk Mode Service" >> /etc/systemd/system/kiosk.service && \
    echo "Requires=lightdm.service" >> /etc/systemd/system/kiosk.service && \
    echo "After=lightdm.service network.target" >> /etc/systemd/system/kiosk.service && \
    echo "" >> /etc/systemd/system/kiosk.service && \
    echo "[Service]" >> /etc/systemd/system/kiosk.service && \
    echo "Type=simple" >> /etc/systemd/system/kiosk.service && \
    echo "ExecStart=/bin/true" >> /etc/systemd/system/kiosk.service && \
    echo "RemainAfterExit=yes" >> /etc/systemd/system/kiosk.service && \
    echo "" >> /etc/systemd/system/kiosk.service && \
    echo "[Install]" >> /etc/systemd/system/kiosk.service && \
    echo "WantedBy=graphical.target" >> /etc/systemd/system/kiosk.service

# Enable the kiosk service
RUN systemctl enable kiosk.service
RUN systemctl enable lightdm.service

# Ensure proper permissions
RUN chown -R kiosk:kiosk /home/kiosk/

# Clean up
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the stop signal and command
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]