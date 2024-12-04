#!/bin/bash
# Function to add directories to volume mounts array
add_directories_to_volume_mounts() {
  local dir_path=$1
  local mount_path=$2
  local -n volume_mounts=$3

  echo "Adding directories from ${dir_path} to volume mounts..."
  if sudo [ -d "${dir_path}" ] && sudo [ "$(sudo ls -A "${dir_path}")" ]; then
    while IFS= read -r -d '' dir; do
      BASENAME=$(basename "${dir}")
      echo "${BASENAME}"
      volume_mounts+=("-v \"${dir}\":\"${mount_path}/${BASENAME}\"")
    done < <(sudo find "${dir_path}" -mindepth 1 -maxdepth 1 -type d -print0 | tr '\n' '\0')
  else
    echo "No directories found in ${dir_path}."
  fi
}

# Function to copy and set permissions for XML files
copy_and_set_permissions() {
  local source_file=$1
  local target_file=$2

  if sudo [ ! -f "${target_file}" ]; then
    echo "Copying $(basename "${source_file}")..."
    sudo cp "${source_file}" "${target_file}"
    sudo chmod 660 "${target_file}"
    sudo chown ${THIS_UID}:${THIS_GID} "${target_file}"
  else
    echo "${target_file} already exists. Skipping copy and modifications."
  fi
}

# Function to create a directory with specified permissions and ownership
create_directory() {
  local dir_path=$1
  if sudo [ ! -d "${dir_path}" ]; then
    sudo mkdir -p ${dir_path}
    sudo chmod ${DIR_PERMISSIONS} ${dir_path}
    sudo chown ${THIS_UID}:${THIS_GID} ${dir_path}
  fi
}

# Function to detect boolean values
detect_bool() {
  local value=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$value" in
    "y"|"yes"|"true"|"1")
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

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

# Function to validate integers
validate_integers() {
  local integer=$1
  local integer_name=$2

  if ! [[ "${integer}" =~ ^[0-9]+$ ]] || [ "${integer}" -lt 1 ]; then
    ouput_long_text "Error: ${integer_name} '${integer}' is not a valid integer. Please provide a positive integer."
    exit 1
  fi
}

# Default variable values including the local user account and group. These should match the account and group defined in the Docker image.
USER_ACCOUNT="steam"
GROUP_NAME="steam"
IMAGE_NAME="7d2d-server:latest"
CONTAINER_NAME="7d2d-server"
SERVER_NUMBER=1
EXTERNAL_BASE_GAME_PORT=26900 # This defines the base game port external to the Docker container.
EXTERNAL_BASE_WEB_PORT=8080 # This also defines the telnet port as the web port + 1.
DIR_PERMISSIONS=770
UPDATE_GAME_SERVER=0

# Parse command line arguments
while getopts "u:g:i:c:n:e:w:d:m:a:p:t:" opt; do
  case ${opt} in
    u )
      USER_ACCOUNT=${OPTARG}
      GROUP_NAME=$(id -gn ${USER_ACCOUNT}) # Default group name to match the primary group of the user account
      ;;
    g )
      GROUP_NAME=${OPTARG}
      ;;
    i )
      IMAGE_NAME=${OPTARG}
      ;;
    c )
      CONTAINER_NAME=${OPTARG}
      ;;
    n )
      SERVER_NUMBER=${OPTARG}
      ;;
    e )
      EXTERNAL_BASE_GAME_PORT=${OPTARG}
      ;;
    w )
      EXTERNAL_BASE_WEB_PORT=${OPTARG}
      ;;
    d )
      DATA_DIR=${OPTARG}
      ;;
    m )
      MODS_DIR=${OPTARG}
      ;;
    a )
      MAPS_DIR=${OPTARG}
      ;;
    p )
      DIR_PERMISSIONS=${OPTARG}
      ;;
    t )
      UPDATE_GAME_SERVER=${OPTARG}
      ;;
    \? )
      echo "Usage: $(basename "$0") [-u user_account] [-g group_name] [-i image_name] [-c container_name] [-n server_number] [-e external_base_game_port] [-w external_base_web_port] [-d data_dir] [-m mods_dir] [-a maps_dir] [-p dir_permissions] [-t update_game_server]"
      exit 1
      ;;
  esac
done

if [ -z "${DATA_DIR}" ]; then
  DATA_DIR="$(eval echo ~$USER_ACCOUNT)/game-servers/${CONTAINER_NAME}/data"
fi
if [ -z "${MODS_DIR}" ]; then
  MODS_DIR="$(eval echo ~$USER_ACCOUNT)/game-servers/${CONTAINER_NAME}/mods"
fi
if [ -z "${MAPS_DIR}" ]; then
  MAPS_DIR="$(eval echo ~$USER_ACCOUNT)/game-servers/${CONTAINER_NAME}/maps"
fi

# Check if the CONTAINER_NAME is compliant with Docker container name requirements
if [[ ! "${CONTAINER_NAME}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]+$ ]]; then
  ouput_long_text "Error: CONTAINER_NAME '${CONTAINER_NAME}' is not compliant with Docker container name requirements."
  ouput_long_text "Please use a name that starts with an alphanumeric character and contains only alphanumeric characters, dots, dashes, and underscores."
  exit 1
fi

# Validate variables which should be positive integers
validate_integers "${SERVER_NUMBER}" "SERVER_NUMBER"
validate_integers "${EXTERNAL_BASE_GAME_PORT}" "EXTERNAL_BASE_GAME_PORT"
validate_integers "${EXTERNAL_BASE_WEB_PORT}" "EXTERNAL_BASE_WEB_PORT"

# Check for spaces in directory paths and exit if any are found
invalid_paths=()
if [[ "${DATA_DIR}" =~ \  ]]; then
  invalid_paths+=("DATA_DIR")
fi
if [[ "${MODS_DIR}" =~ \  ]]; then
  invalid_paths+=("MODS_DIR")
fi
if [[ "${MAPS_DIR}" =~ \  ]]; then
  invalid_paths+=("MAPS_DIR")
fi

if [ ${#invalid_paths[@]} -ne 0 ]; then
  ouput_long_text "Error: The following directory paths contain spaces:"
  for path in "${invalid_paths[@]}"; do
    echo "  ${path}=${!path}"
    dash_case=$(echo "${!path}" | tr ' ' '-')
    ouput_long_text "  Suggested dash-case alternative: ${dash_case}"
    camelcase=$(echo "${!path}" | sed -r 's/(^| )([a-z])/\U\2/g' | sed 's/ //g')
    ouput_long_text "  Suggested camelCase alternative: ${camelcase}"
  done
  ouput_long_text "Please use dash-case, camelCase, or another format that does not include spaces."
  exit 1
fi

# Echo the current variables and their values
echo "Using the following variable values:"
echo "  USER_ACCOUNT=${USER_ACCOUNT}"
echo "  GROUP_NAME=${GROUP_NAME}"
echo "  IMAGE_NAME=${IMAGE_NAME}"
echo "  CONTAINER_NAME=${CONTAINER_NAME}"
echo "  SERVER_NUMBER=${SERVER_NUMBER}"
echo "  EXTERNAL_BASE_GAME_PORT=${EXTERNAL_BASE_GAME_PORT}¹"
echo "  EXTERNAL_BASE_WEB_PORT=${EXTERNAL_BASE_WEB_PORT}¹"
echo "  DATA_DIR=${DATA_DIR}"
echo "  MODS_DIR=${MODS_DIR}"
echo "  MAPS_DIR=${MAPS_DIR}"
echo "  DIR_PERMISSIONS=${DIR_PERMISSIONS}"
echo "  UPDATE_GAME_SERVER=${UPDATE_GAME_SERVER}"
ouput_long_text '¹ (NOTE: This value is used as a base for calculating the actual ports the server will use. The actual ports will be derived from this base value and the server number.)'
echo
# Check if the script is run as root or with sudo privileges
if [ "$EUID" -ne 0 ]; then
  ouput_long_text "As directories may be created and directory permissions changed, this script requires elevated permissions to allow these portions of the script to function as expected."
fi

# Check if the script is run as root or with sudo privileges.
if [ "$EUID" -ne 0 ] && ! sudo -v > /dev/null 2>&1; then
  ouput_long_text "Please run the script with sudo (preferred) or as root."
  exit 1
fi

# Update the UPDATE_GAME_SERVER value by passing it to the detect_bool function and setting the value to the output of the function
detect_bool ${UPDATE_GAME_SERVER}
UPDATE_GAME_SERVER=$?

# The SERVER_BASE_NUM is the base number used to calculate the ports for the server.
# It is derived from the SERVER_NUMBER and helps in dynamically setting the ports.
SERVER_BASE_NUM=$(((${SERVER_NUMBER} - 1) * 3))
SERVER_BASE_WEB_NUM=$(((${SERVER_NUMBER} - 1) * 2))

# Update THIS_UID and THIS_GID based on the provided user and group names
if id "${USER_ACCOUNT}" &>/dev/null; then
  THIS_UID=$(id -u ${USER_ACCOUNT})
else
  ouput_long_text "Error: User account '${USER_ACCOUNT}' does not exist. Please double-check the user account name."
  exit 1
fi

if getent group "${GROUP_NAME}" &>/dev/null; then
  THIS_GID=$(getent group "${GROUP_NAME}" | cut -d: -f3)
else
  ouput_long_text "Error: Group name '${GROUP_NAME}' does not exist. Please double-check the group name."
  exit 1
fi

# Create necessary directories with appropriate permissions and ownership
create_directory "${DATA_DIR}"
create_directory "${DATA_DIR}/Saves"
create_directory "${MODS_DIR}"
create_directory "${MAPS_DIR}"

# Check if a container with the same name is already running
if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
  ouput_long_text "A Docker container with the name '${CONTAINER_NAME}' is already running. This container will be stopped and replaced with the new container."
  read -p "Do you want to continue? (y/n): " choice
  case "$choice" in 
    y|Y|yes|YES )
      echo "Proceeding with the replacement of the container..."
      ;;
    * )
      ouput_long_text "Operation cancelled by the user."
      exit 0
      ;;
  esac
fi

# This stops and removes the Docker container if it is already running.
if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
  echo "Stopping Docker container (${CONTAINER_NAME})..."
  docker stop ${CONTAINER_NAME} > /dev/null 2>&1
fi
if [ "$(docker ps -a -q -f name=${CONTAINER_NAME})" ]; then
  echo "Removing Docker container (${CONTAINER_NAME})..."
  docker rm ${CONTAINER_NAME} > /dev/null 2>&1
fi

# An array to store volume mount paths for the Docker container
VOLUME_MOUNTS=()

# Add mod directories to VOLUME_MOUNTS
add_directories_to_volume_mounts "${MODS_DIR}" "/7d2d/Mods" VOLUME_MOUNTS

# Add map directories to VOLUME_MOUNTS
add_directories_to_volume_mounts "${MAPS_DIR}" "/7d2d/Data/Worlds" VOLUME_MOUNTS

# Copy the serverconfig.xml file from the xml directory if it does not exist in the data directory.
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
copy_and_set_permissions "${SCRIPT_DIR}/xml/serverconfig.xml" "${DATA_DIR}/serverconfig.xml"

# Copy the serveradmin.xml file from the xml directory if it does not exist in the ${DATA_DIR}/Saves directory.
copy_and_set_permissions "${SCRIPT_DIR}/xml/serveradmin.xml" "${DATA_DIR}/Saves/serveradmin.xml"

# This portion of the script runs a Docker container for a 7 Days to Die server.
# It performs the following actions:
# 1. Prints a message indicating the Docker container is being run.
# 2. Uses `docker run` to start the container in detached mode (`-d`).
# 3. Maps the necessary TCP and UDP ports for the game server, dynamically adjusting based on `SERVER_BASE_NUM`.
# 4. Maps an external web port for the server's web interface, dynamically adjusting based on `EXTERNAL_BASE_WEB_PORT` and `SERVER_NUMBER`.
#    Note: The web interface must be enabled in the serverconfig.xml file.
# 5. Maps an external telnet port for the server's telnet interface, dynamically adjusting based on `EXTERNAL_BASE_WEB_PORT`+1 and `SERVER_NUMBER`.
#    Note: The telnet interface must be enabled in the serverconfig.xml file.
# 6. Sets the container name using `CONTAINER_NAME`.
# 7. Sets the user and group IDs for the container using `THIS_UID` and `THIS_GID`.
# 8. Configures the container to always restart using `--restart always`.
# 9. Mounts the data directory to `/data` inside the container.
# 10. Adds any additional volume mounts specified in `VOLUME_MOUNTS`.
# 11. Uses the specified Docker image `IMAGE_NAME` to create the container.
# 12. Passes the `UPDATE_GAME_SERVER` variable to the container.
echo "Running Docker container..."
eval docker run -d \
  -p $(( ${EXTERNAL_BASE_GAME_PORT} + ${SERVER_BASE_NUM} )):26900/tcp \
  -p $(( ${EXTERNAL_BASE_GAME_PORT} + ${SERVER_BASE_NUM} )):26900/udp \
  -p $(( ${EXTERNAL_BASE_GAME_PORT} + ${SERVER_BASE_NUM} + 1 )):26901/udp \
  -p $(( ${EXTERNAL_BASE_GAME_PORT} + ${SERVER_BASE_NUM} + 2 )):26902/udp \
  -p $(( ${EXTERNAL_BASE_WEB_PORT} + ${SERVER_BASE_WEB_NUM} )):8080/tcp \
  -p $(( ${EXTERNAL_BASE_WEB_PORT} + ${SERVER_BASE_WEB_NUM} + 1 )):8081/tcp \
  --name "${CONTAINER_NAME}" \
  --user ${THIS_UID}:${THIS_GID} \
  --restart always \
  -v "${DATA_DIR}:/data" \
  "${VOLUME_MOUNTS[@]}" \
  -e UPDATE_GAME_SERVER=${UPDATE_GAME_SERVER} \
  ${IMAGE_NAME}

# Output a message indicating the Docker container has been started.
ouput_long_text "Docker container '${CONTAINER_NAME}' has been started. Use 'docker logs ${CONTAINER_NAME}' to view the server output."
ouput_long_text "You may also use 'docker logs -f ${CONTAINER_NAME}' to view and follow the server output."

# Output a list of ports which need to be opened on the firewall.
ouput_long_text "  Open the following ports on your firewall(s) to allow the server to be available to others:"
echo "    $(( ${EXTERNAL_BASE_GAME_PORT} + ${SERVER_BASE_NUM} ))/tcp"
echo "    $(( ${EXTERNAL_BASE_GAME_PORT} + ${SERVER_BASE_NUM} ))/udp"
echo "    $(( ${EXTERNAL_BASE_GAME_PORT} + ${SERVER_BASE_NUM} + 1 ))/udp"
echo "    $(( ${EXTERNAL_BASE_GAME_PORT} + ${SERVER_BASE_NUM} + 2 ))/udp"
echo "    $(( ${EXTERNAL_BASE_WEB_PORT} + ${SERVER_BASE_WEB_NUM} )) (optional: web interface)"
echo "    $(( ${EXTERNAL_BASE_WEB_PORT} + ${SERVER_BASE_WEB_NUM} + 1 )) (optional: telnet interface)"
