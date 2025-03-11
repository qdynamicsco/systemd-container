# Use a glibc-based lightweight base image
FROM ubuntu:22.04

# Set environment variables to prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && apt-get install -y \
    chromium-browser \
    weston \
    libwayland-client0 \
    libwayland-server0 \
    libegl1 \
    libgles2 \
    mesa-utils \
    dbus \
    supervisor \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create necessary directories for logging
RUN mkdir -p /var/log

# Copy the startup script into the container
COPY start.sh /start.sh

# Ensure the startup script is executable
RUN chmod +x /start.sh

# Set the entrypoint to the startup script
CMD ["/start.sh"]