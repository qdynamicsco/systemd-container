#!/bin/bash
set -eo pipefail

# 1. Start SSH server
echo "Starting SSH server..."
mkdir -p /run/sshd
/usr/sbin/sshd -D &

echo "Cleaning up lingering CNI bridge interface..."
ip link delete nerdctl0 > /dev/null 2>&1 || true

# 2. Start containerd
echo "Starting containerd..."
containerd &
CONTAINERD_PID=$!

# === SECTION: GENERATE DYNAMIC WEBSITE ===
echo "Reading hardware info and generating index.html..."
# Use an if statement for safety with 'set -e'
if [ -f /sys/class/dmi/id/product_name ]; then
    export PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name)
else
    export PRODUCT_NAME="N/A"
fi
if [ -f /sys/class/dmi/id/product_serial ]; then
    export PRODUCT_SERIAL=$(cat /sys/class/dmi/id/product_serial)
else
    export PRODUCT_SERIAL="N/A"
fi

envsubst < /var/www/index.template.html > /var/www/index.html
echo " - Product: $PRODUCT_NAME, Serial: $PRODUCT_SERIAL"

echo "Applying correct permissions to web root..."
chmod -R a+rX /var/www

# 3. Wait for containerd socket
echo "Waiting for containerd socket at /run/containerd/containerd.sock..."
while [ ! -S /run/containerd/containerd.sock ]; do
  if ! ps -p $CONTAINERD_PID > /dev/null; then echo "containerd process died."; exit 1; fi
  echo -n "."; sleep 0.5;
done
echo "Containerd is running!"

# 4. Define images and pull them
NGINX_IMAGE="docker.io/library/nginx:latest"
CHROME_IMAGE="ghcr.io/qdynamicsco/systemd-container/systemd-container:min-chrome"

echo "Pulling inner containers using 'native' snapshotter..."
nerdctl --snapshotter=native pull $NGINX_IMAGE
nerdctl --snapshotter=native pull $CHROME_IMAGE

# 5. Start inner containers
echo "Starting inner containers using 'native' snapshotter..."
nerdctl --snapshotter=native run -d --name nginx \
  --mount type=bind,source=/var/www,target=/usr/share/nginx/html,readonly \
  $NGINX_IMAGE

# Chrome container is unchanged
nerdctl --snapshotter=native run -d --name chrome-ui --privileged -v /dev:/dev -e KIOSK_URL=http://nginx:80 $CHROME_IMAGE

echo "Inner containers started. Listing them with 'nerdctl ps':"
nerdctl ps -a

echo "-----------------------------------------------------"
echo "Setup complete. Container is running."
echo "-----------------------------------------------------"
ip a

# 6. Wait for the primary process (containerd) to exit.
wait $CONTAINERD_PID
