# Dockerfile for 7 Days to Die Dedicated Server using the latest Ubuntu Server as the base

# Use the latest Ubuntu Server as the base image
FROM ubuntu:latest

# Set build arguments with default values
ARG USER=steam
ARG UID=1001
ARG GID=1001

# Set environment variables
ENV STEAM_USERNAME="anonymous"
ENV STEAM_APP_ID="294420"
ENV SERVER_INSTALL_DIR="/7d2d"
ENV LD_LIBRARY_PATH="$SERVER_INSTALL_DIR"

# Update and install required packages
RUN apt-get update && \
    apt-get install -y wget curl unzip lib32gcc-s1 software-properties-common && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create a group and user with the specified GID and UID if they do not exist
RUN if ! getent group $GID; then groupadd -g $GID $USER; fi && \
    if ! id -u $UID >/dev/null 2>&1; then useradd -m -u $UID -g $GID -s /bin/bash $USER; fi

# Install SteamCMD
RUN mkdir -p /steamcmd && \
    cd /steamcmd && \
    wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz && \
    tar -xvzf steamcmd_linux.tar.gz && \
    rm steamcmd_linux.tar.gz && \
    chown -R $UID:$GID /steamcmd

# Create server install directory and set ownership and permissions
RUN mkdir -p $SERVER_INSTALL_DIR && \
    chown -R $UID:$GID $SERVER_INSTALL_DIR && \
    chmod -R 755 $SERVER_INSTALL_DIR

# Install 7 Days to Die server as the specified user
USER $USER
RUN /steamcmd/steamcmd.sh +force_install_dir $SERVER_INSTALL_DIR +login $STEAM_USERNAME +app_update $STEAM_APP_ID validate +quit
USER root

# Set working directory
WORKDIR $SERVER_INSTALL_DIR

# Copy the start script
COPY start_server.sh /start_server.sh
RUN chmod +x /start_server.sh

# Expose ports for 7 Days to Die server
# - 26900 TCP: Game (Game details query port)
# - 26900 UDP: Game (Steam's master server list interface)
# - 26901 UDP: Game (Steam communication)
# - 26902 UDP: Game (networking via LiteNetLib)
# - 8080 TCP: Web control panel (optional)
# - 8081 TCP: Telnet control (optional)
EXPOSE 26900/tcp 26900/udp 26901/udp 26902/udp 8080/tcp 8081/tcp

# Set entrypoint to start the server
ENTRYPOINT ["/start_server.sh"]