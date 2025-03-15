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
RUN git clone https://github.com/georgmartius/lpzrobots.git

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
