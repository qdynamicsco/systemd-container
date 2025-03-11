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

# Create necessary directories for supervisord
RUN mkdir -p /var/log/supervisor

# Supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Configure Weston to use the DRM backend
ENV XDG_RUNTIME_DIR=/tmp/weston
RUN mkdir -p $XDG_RUNTIME_DIR
ENV WAYLAND_DISPLAY=wayland-0

# Set permissions for Weston
RUN chown root:root $XDG_RUNTIME_DIR && chmod 700 $XDG_RUNTIME_DIR

# Grant necessary capabilities and device access
# These will be specified when running the container

# Expose any necessary ports (if needed)
# EXPOSE 8080

# Set the entrypoint to supervisord
CMD ["/usr/bin/supervisord"]