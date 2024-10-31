# Use Ubuntu as base image
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    systemd \
    systemd-sysv \
    docker.io \
    iproute2 \
    openssh-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a user for login purposes and set password
RUN useradd -m dockeruser && echo "dockeruser:dockerpassword" | chpasswd && \
    usermod -aG sudo dockeruser

# Enable getty on /dev/pts/0
RUN systemctl enable getty@tty1.service

# Set up SSH
RUN mkdir /var/run/sshd && \
    mkdir -p /home/dockeruser/.ssh && \
    chown dockeruser:dockeruser /home/dockeruser/.ssh && \
    chmod 700 /home/dockeruser/.ssh

# Add your SSH public key here
ADD https://github.com/danward.keys /home/dockeruser/.ssh/authorized_keys
RUN chown dockeruser:dockeruser /home/dockeruser/.ssh/authorized_keys && \
    chmod 600 /home/dockeruser/.ssh/authorized_keys

# Set the default entrypoint to systemd
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
