#!/bin/bash

# Define the configuration file as mapped in the Docker container
CONFIG_FILE="/data/serverconfig.xml"

# Other required vars - this should match the Dockerfile
STEAM_USERNAME="anonymous"
STEAM_APP_ID="294420"
SERVER_INSTALL_DIR="/7d2d"

# Set the LD_LIBRARY_PATH environment variable to the server installation directory.
# This is necessary to ensure that the server can locate and use the correct shared libraries during execution.
LD_LIBRARY_PATH="${SERVER_INSTALL_DIR}"

# Update the game server if UPDATE_GAME_SERVER environment variable is set to 1
if [ "$UPDATE_GAME_SERVER" == "1" ]; then
    /steamcmd/steamcmd.sh +force_install_dir ${SERVER_INSTALL_DIR} +login ${STEAM_USERNAME} +app_update ${STEAM_APP_ID} validate +quit
fi

# Run the 7 Days to Die server
cd /7d2d
./7DaysToDieServer.x86_64 -logfile /dev/stdout -configfile=${CONFIG_FILE} -quit -batchmode -nographics -dedicated