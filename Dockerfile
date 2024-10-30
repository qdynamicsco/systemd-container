# Use Ubuntu as base image
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y systemd systemd-sysv docker.io iproute2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a user for login purposes
RUN useradd -m dockeruser && echo "dockeruser:dockerpassword" | chpasswd && \
    usermod -aG sudo dockeruser

# Set the default entrypoint to systemd
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
