# docker-ubuntu-arm64-vnc-rdp
Connect to docker container running Ubuntu image on Mac M4 arm64 with port forwarding for VNC and XRDP viewer to connect on client.

Below is an updated solution that adds RDP support via xrdp. In this configuration, we install the xrdp package and modify its configuration so that RDP connections are forwarded to the existing VNC server (running on display :0 via x11vnc). This lets you use Microsoft Remote Desktop (or any RDP client) to connect to your container’s desktop session.

Both the Dockerfile and the entrypoint script have been updated accordingly. (Make sure you rebuild your image after these changes.)

⸻

Dockerfile

# Use Ubuntu 18.04 as the base image
FROM ubuntu:18.04

# Use bash for RUN commands
SHELL ["/bin/bash", "-c"]

# Set locale and noninteractive mode
ENV LANG=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# Update package lists and install essential packages including VNC, RDP, SSH, XFCE4, and lpzrobots dependencies.
RUN apt-get update && \
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        wget \
        curl \
        unzip \
        git \
        locales \
        sudo \
        build-essential \
        xfce4 \
        xfce4-terminal \
        xvfb \
        x11vnc \
        xrdp \
        openssh-server \
        g++ \
        make \
        automake \
        libtool \
        xutils-dev \
        m4 \
        libreadline-dev \
        libgsl0-dev \
        libglu-dev \
        libgl1-mesa-dev \
        freeglut3-dev \
        libopenscenegraph-dev \
        libqt4-dev \
        libqt4-opengl \
        libqt4-opengl-dev \
        qt4-qmake \
        libqt4-qt3support \
        gnuplot \
        gnuplot-x11 \
        libncurses5-dev && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# --- Setup SSH ---
# Create SSH runtime directory and allow root login if needed
RUN mkdir -p /var/run/sshd && \
    echo 'root:password' | chpasswd && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- Create non-root user "user" with password "123456" ---
RUN useradd -m -s /bin/bash user && \
    echo "user:123456" | chpasswd && \
    adduser user sudo

# --- Download and install lpzrobots ---
WORKDIR /opt
RUN wget https://github.com/georgmartius/lpzrobots/archive/master.zip && \
    unzip master.zip && \
    mv lpzrobots-master lpzrobots && \
    rm master.zip

WORKDIR /opt/lpzrobots
# Install the build dependencies for lpzrobots (repeat the list for full compatibility)
RUN apt-get update && \
    apt-get install -y \
        g++ \
        make \
        automake \
        libtool \
        xutils-dev \
        m4 \
        libreadline-dev \
        libgsl0-dev \
        libglu-dev \
        libgl1-mesa-dev \
        freeglut3-dev \
        libopenscenegraph-dev \
        libqt4-dev \
        libqt4-opengl \
        libqt4-opengl-dev \
        qt4-qmake \
        libqt4-qt3support \
        gnuplot \
        gnuplot-x11 \
        libncurses5-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure and build lpzrobots (for development mode)
RUN prefix="/usr/local" && \
    echo "PREFIX=$prefix" > Makefile.conf && \
    echo "TYPE=DEVEL" >> Makefile.conf && \
    make && make all

# Configure xrdp to use VNC (the libvnc.so module) to connect to display :0.
# This appends a new session in /etc/xrdp/xrdp.ini.
RUN echo "\n[xrdp1]\nname=VNC\nlib=libvnc.so\nusername=ask\npassword=ask\nip=127.0.0.1\nport=5900" >> /etc/xrdp/xrdp.ini

# Expose VNC (5900), SSH (22) and RDP (3389) ports
EXPOSE 5900 22 3389

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the working directory to the lpzrobots source (or your development folder)
WORKDIR /opt/lpzrobots

# Start the container via the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]



⸻

entrypoint.sh

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



⸻

How to Build and Run
	1.	Build the Image
In the directory containing the Dockerfile and entrypoint.sh, run:

docker build -t lpzrobots-vnc-rdp .


	2.	Run the Container with Port Mapping and Bind Mount
For example, if your local lpzrobots code is in ~/lpzrobots:

docker run -d \
  -p 5900:5900 \
  -p 2222:22 \
  -p 3389:3389 \
  --name lpzrobot \
  -v ~/lpzrobots:/opt/lpzrobots \
  lpzrobots-vnc-rdp

(Here, container SSH port 22 is mapped to host port 2222; adjust as desired.)

	3.	Connect from Your Mac
	•	VNC Access:
Use your VNC client (e.g., TigerVNC or RealVNC) to connect to:

localhost:5900

with password 123456.

	•	RDP Access:
Open Microsoft Remote Desktop (or another RDP client) on your Mac and connect to:

localhost:3389

When prompted, enter the credentials (xrdp is set to ask for username/password; use user/123456).

	•	SSH Access:
Connect via SSH:

ssh user@localhost -p 2222

using password 123456.

⸻

Explanation
	•	xrdp Configuration:
The Dockerfile appends a new session section in /etc/xrdp/xrdp.ini that uses the VNC module (libvnc.so) to forward RDP connections to the VNC server running on display :0.
	•	Service Startup:
The entrypoint script starts Xvfb and the XFCE4 desktop session, then x11vnc to serve the desktop via VNC, and finally starts the xrdp daemon so that RDP connections (on port 3389) connect to the VNC session.
	•	Port Exposure:
Ports 5900 (VNC), 22 (SSH), and 3389 (RDP) are exposed and mapped to the host so you can choose your preferred remote access method.

This configuration should provide a working environment where you can connect via VNC or RDP from your Mac, while still having SSH access for terminal work.
