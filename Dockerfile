# Use Ubuntu 24.04 as base image
FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    systemd \
    systemd-sysv \
    kmod \
    ethtool \
    ubuntu-desktop-minimal \
    iproute2 \
    openssh-server \
    sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a user for login purposes and set password
RUN useradd -m qd && \
    echo "qd:qdpassword" | chpasswd && \
    usermod -aG sudo qd

# Set the default shell for qd to bash
RUN chsh -s /bin/bash qd

# Enable getty on /dev/pts/0
# RUN systemctl enable getty@tty1.service

# Set up SSH
RUN mkdir /var/run/sshd && \
    mkdir -p /home/qd/.ssh && \
    chown qd:qd /home/qd/.ssh && \
    chmod 700 /home/qd/.ssh

# Add SSH public keys for danward and alexanderturner
ADD https://github.com/danward.keys /home/qd/.ssh/authorized_keys
ADD https://github.com/alexanderturner.keys /home/qd/.ssh/authorized_keys_alex
RUN cat /home/qd/.ssh/authorized_keys_alex >> /home/qd/.ssh/authorized_keys && \
    rm /home/qd/.ssh/authorized_keys_alex && \
    chown qd:qd /home/qd/.ssh/authorized_keys && \
    chmod 600 /home/qd/.ssh/authorized_keys

# Disable screen timeout and screen saver for Xfce
RUN mkdir -p /home/qd/.config/xfce4/xfconf/xfce-perchannel-xml && \
    echo '<?xml version="1.0" encoding="UTF-8"?>' > /home/qd/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    echo '<channel name="xfce4-power-manager" version="1.0"><property name="locking" type="bool" value="false"/><property name="dpms-on-ac-sleep" type="int" value="0"/><property name="dpms-on-ac-off" type="int" value="0"/></channel>' >> /home/qd/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml && \
    chown -R qd:qd /home/qd/.config

# Set up LightDM to use xfce session
# RUN echo "[Seat:*]" > /etc/lightdm/lightdm.conf.d/60-xfce4.conf && \
#     echo "session-wrapper=/etc/X11/Xsession" >> /etc/lightdm/lightdm.conf.d/60-xfce4.conf && \
#     echo "user-session=xfce" >> /etc/lightdm/lightdm.conf.d/60-xfce4.conf

# Set the default entrypoint to systemd
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]