# Use Debian Bookworm as base image (ARM64 compatible)
FROM debian:bookworm

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV KIOSK_URL="https://google.com"
# Redirect cache locations to writable areas
ENV HOME=/tmp
ENV XDG_RUNTIME_DIR=/tmp/xdg
ENV XDG_CACHE_HOME=/tmp/.cache
ENV FONTCONFIG_PATH=/etc/fonts

# Install X11 with framebuffer support, Chromium, and GPU support
RUN apt-get update && apt-get install -y \
    chromium \
    xserver-xorg-core \
    xserver-xorg-video-fbdev \
    xserver-xorg-input-libinput \
    xserver-xorg-input-evdev \
    x11-xserver-utils \
    xinit \
    openbox \
    openssh-server \
    dbus \
    dbus-x11 \
    udev \
    acl \
    sudo \
    input-utils \
    fonts-noto \
    pulseaudio \
    xdg-utils \
    mesa-utils \
    mesa-va-drivers \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup input permissions
RUN groupadd -f input && \
    usermod -a -G input,video,tty root

# Create udev rules for input devices
RUN mkdir -p /etc/udev/rules.d && \
    echo 'SUBSYSTEM=="input", MODE="0666"' > /etc/udev/rules.d/99-input.rules

# Setup SSH
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Add SSH public keys 
ADD https://github.com/danward.keys /root/.ssh/authorized_keys
ADD https://github.com/alexanderturner.keys /root/.ssh/authorized_keys_alex
RUN cat /root/.ssh/authorized_keys_alex >> /root/.ssh/authorized_keys && \
    rm /root/.ssh/authorized_keys_alex && \
    chown root:root /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys

# Create necessary directories for logging
RUN mkdir -p /var/log/container

# Create X11 configuration for framebuffer and input
RUN mkdir -p /etc/X11/xorg.conf.d && \
    echo 'Section "Device"\n\
    Identifier "Framebuffer"\n\
    Driver "fbdev"\n\
    Option "fbdev" "/dev/fb0"\n\
EndSection' > /etc/X11/xorg.conf.d/99-fbdev.conf && \
    echo 'Section "InputClass"\n\
    Identifier "evdev keyboard catchall"\n\
    MatchIsKeyboard "on"\n\
    MatchDevicePath "/dev/input/event*"\n\
    Driver "evdev"\n\
    Option "GrabDevice" "true"\n\
EndSection\n\
\n\
Section "InputClass"\n\
    Identifier "evdev pointer catchall"\n\
    MatchIsPointer "on"\n\
    MatchDevicePath "/dev/input/event*"\n\
    Driver "evdev"\n\
    Option "GrabDevice" "true"\n\
EndSection' > /etc/X11/xorg.conf.d/10-input.conf

# Create a minimal openbox menu to avoid error
RUN mkdir -p /etc/xdg/openbox && \
    echo '<?xml version="1.0" encoding="UTF-8"?>\n\
<openbox_menu>\n\
<menu id="root-menu" label="Openbox">\n\
  <item label="Terminal">\n\
    <action name="Execute"><command>xterm</command></action>\n\
  </item>\n\
</menu>\n\
</openbox_menu>' > /etc/xdg/openbox/menu.xml

# Create openbox configuration
RUN mkdir -p /etc/xdg/openbox && \
    echo '<?xml version="1.0" encoding="UTF-8"?>\n\
<openbox_config xmlns="http://openbox.org/3.4/rc">\n\
  <resistance>\n\
    <strength>10</strength>\n\
    <screen_edge_strength>20</screen_edge_strength>\n\
  </resistance>\n\
  <focus>\n\
    <focusNew>yes</focusNew>\n\
    <followMouse>no</followMouse>\n\
  </focus>\n\
  <placement>\n\
    <policy>Smart</policy>\n\
  </placement>\n\
  <theme>\n\
    <name>Clearlooks</name>\n\
    <keepBorder>no</keepBorder>\n\
    <animateIconify>yes</animateIconify>\n\
  </theme>\n\
  <applications>\n\
    <application class="*">\n\
      <decor>no</decor>\n\
      <maximized>true</maximized>\n\
    </application>\n\
  </applications>\n\
</openbox_config>' > /etc/xdg/openbox/rc.xml

# Pre-create .xinitrc file with improved Chromium options
COPY xinit.rc /root/.xinitrc
RUN chmod +x /root/.xinitrc

# Modify sshd_config for read-only operation
RUN sed -i 's/#PidFile/PidFile/' /etc/ssh/sshd_config && \
    sed -i 's|#ChrootDirectory none|ChrootDirectory none|' /etc/ssh/sshd_config && \
    echo "UsePrivilegeSeparation no" >> /etc/ssh/sshd_config

# Copy start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set the entrypoint
CMD ["/start.sh"]