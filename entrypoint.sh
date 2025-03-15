#!/bin/bash
set -e

# Start the SSH server
echo "Starting SSH server..."
/usr/sbin/sshd

# Start Xvfb on display :0
export DISPLAY=:0
echo "Starting Xvfb on display :0..."
Xvfb :0 -screen 0 1024x768x16 &
sleep 3

# Start the XFCE4 desktop session (using xfce4-session directly)
echo "Starting XFCE4 session..."
xfce4-session &
sleep 5

# Set up the VNC password (using the same as user credentials: 123456)
VNC_PASSWORD="123456"
echo "Setting up VNC password..."
x11vnc -storepasswd "$VNC_PASSWORD" /tmp/vncpass.txt

# Start x11vnc on display :0 with recommended options
echo "Starting x11vnc on display :0 (port 5900)..."
x11vnc -display :0 -rfbauth /tmp/vncpass.txt -forever -noxdamage -shared -rfbport 5900 &
sleep 2

# Start the xrdp service in the background.
# xrdp will use the configuration added in /etc/xrdp/xrdp.ini to connect to the VNC session.
echo "Starting xrdp service (RDP on port 3389)..."
/usr/sbin/xrdp &
sleep 2

echo "Container started. SSH is on port 22, VNC is on port 5900, and RDP is on port 3389."
tail -f /dev/null
