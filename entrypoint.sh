#!/bin/bash
set -eo pipefail

# 1. Prepare for and start the SSH server
echo "Starting SSH server..."
mkdir -p /run/sshd
/usr/sbin/sshd -D &

# 2. Start containerd in the background
echo "Starting containerd..."
containerd &
CONTAINERD_PID=$!

# 3. Wait for the containerd socket to be available
echo "Waiting for containerd socket at /run/containerd/containerd.sock..."
while [ ! -S /run/containerd/containerd.sock ]; do
  if ! ps -p $CONTAINERD_PID > /dev/null; then
    echo "containerd process died."
    exit 1
  fi
  echo -n "."
  sleep 0.5
done
echo "Containerd is running!"

# 4. Use nerdctl to confirm containerd is working
echo "Containerd version:"
nerdctl version

# 5. Define inner container images
NGINX_IMAGE="docker.io/library/nginx:latest"
CHROME_IMAGE="ghcr.io/qdynamicsco/systemd-container/systemd-container:min-chrome"

# 6. Pull and run the inner containers, FORCING the 'native' snapshotter
echo "Pulling inner containers using 'native' snapshotter..."
nerdctl --snapshotter=native pull $NGINX_IMAGE
nerdctl --snapshotter=native pull $CHROME_IMAGE

echo "Starting inner containers using 'native' snapshotter..."
nerdctl --snapshotter=native run -d --name nginx -p 8080:80 $NGINX_IMAGE

nerdctl --snapshotter=native run \
  -d \
  --name chrome-ui \
  --privileged \
  --network host \
  -v /dev:/dev \
  -e KIOSK_URL=http://localhost:8080 \
  $CHROME_IMAGE

echo "Inner containers started. Listing them with 'nerdctl ps':"
nerdctl ps -a

echo "-----------------------------------------------------"
echo "Setup complete. Container is running."
echo " - SSH server is running. Connect with: ssh root@<host_ip> -p <mapped_port>"
echo " - Nginx is running, accessible on host port 8080."
echo " - Chrome UI container has been started and should take over a primary display."
echo "-----------------------------------------------------"

# 7. Wait for the primary process (containerd) to exit.
wait $CONTAINERD_PID
