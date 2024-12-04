#!/bin/bash
: '
This script is designed to assist users who are new to Linux in creating a 
user account named "steam" for use with the Docker container for 7 Days to 
Die. The purpose of creating this "steam" user is to enhance the security of 
the Docker container. By running the container as a non-root user (the 
"steam" user), we reduce the risk of potential security vulnerabilities that 
could be exploited if the container were running with root (superuser) 
privileges.
'

# This function outputs a long text message to the console.
ouput_long_text() {
    local input_string="$1"
    local terminal_width=$(tput cols)
    local current_line=""
    
    for word in $input_string; do
        if [ ${#current_line} -eq 0 ]; then
            current_line="$word"
        elif [ $((${#current_line} + ${#word} + 1)) -le $terminal_width ]; then
            current_line="$current_line $word"
        else
            echo "$current_line"
            current_line="$word"
        fi
    done
    
    if [ ${#current_line} -ne 0 ]; then
        echo "$current_line"
    fi
}

# Check if the script is run as root or with sudo privileges
if [ "$EUID" -ne 0 ]; then
  ouput_long_text "As an account and group may be added, this script requires elevated permissions to allow these portions of the script to function as expected."
fi

# Check if the script is run as root or with sudo privileges.
if [ "$EUID" -ne 0 ] && ! sudo -v > /dev/null 2>&1; then
  ouput_long_text "Please run the script with sudo (preferred) or as root."
  exit 1
fi

# Check if the steam user already exists
if id "steam" &>/dev/null; then
    ouput_long_text "The user 'steam' already exists. Skipping user and group creation."
else
    # Check if the steam group exists
    if ! getent group steam &>/dev/null; then
        ouput_long_text "The group 'steam' does not exist. Creating the group."
        sudo groupadd steam
    fi

    # Create the steam user with the steam group as the primary group
    ouput_long_text "Creating the user 'steam' with the 'steam' group as the primary group."
    sudo useradd -m -g steam -s /bin/bash steam
fi

# Get the UID and GID for the user "steam"
USER_UID=$(id -u steam)
GROUP_GID=$(getent group steam | cut -d: -f3)

# Print the UID and GID
echo "User 'steam' has UID: $USER_UID"
echo "Group 'steam' has GID: $GROUP_GID"

# Check if USER_UID or GROUP_GID do not equal 1001 and print the build-arg options accordingly
if [ "$USER_UID" -ne 1001 ] || [ "$GROUP_GID" -ne 1001 ]; then
  ouput_long_text "Please use the following build-arg options when building the Docker image to set the correct UID and GID:"
  echo -n "docker build"
  if [ "$USER_UID" -ne 1001 ]; then
    echo -n " --build-arg UID=$USER_UID"
  fi
  if [ "$GROUP_GID" -ne 1001 ]; then
    echo -n " --build-arg GID=$GROUP_GID"
  fi
  echo " -t 7d2d-server ."
else
  ouput_long_text "The UID and GID for the 'steam' user and group match the default expected values. No further action is required."
fi