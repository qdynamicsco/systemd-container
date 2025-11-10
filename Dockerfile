# Use the latest Ubuntu LTS as the base image
FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set version for nerdctl for consistency
ARG NERDCTL_VERSION="2.2.0"

# 1. Install dependencies: now includes gettext-base for envsubst
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    openssh-server \
    iptables \
    iproute2 \
    gettext-base \
    && \

    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y containerd.io && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 2. Configure SSH Server
RUN echo "Configuring SSH..." && \
    mkdir -p /root/.ssh && chmod 700 /root/.ssh && \
    curl -fsSL https://github.com/danward.keys > /root/.ssh/authorized_keys && \
    curl -fsSL https://github.com/alexanderturner.keys >> /root/.ssh/authorized_keys && \
    chown root:root /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin without-password/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    ssh-keygen -A

# 3. Add the website template files to a directory in the image
COPY www/ /var/www/

# 4. Install nerdctl
RUN curl -fsSL "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz" \
    | tar -C /usr/local -xz

# 5. CNI config
RUN mkdir -p /etc/cni/net.d && \
    echo '{ "cniVersion": "1.0.0", "name": "nerdctl-bridge", "type": "bridge", "bridge": "cni0", "isGateway": true, "ipMasq": true, "ipam": { "type": "host-local", "subnet": "10.4.0.0/24", "routes": [ { "dst": "0.0.0.0/0" } ] } }' \
    > /etc/cni/net.d/10-nerdctl-bridge.conf

# 6. Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 7. Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

EXPOSE 80
EXPOSE 22
