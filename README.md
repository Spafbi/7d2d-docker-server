# 7d2d-docker-server
Automated setup and management of a 7 Days to Die server using Docker.

# Table of contents
- [Requirements](#requirements)
- [Files](#files)
- [Installation and Use Steps](#installation-and-use-steps)
    - [Download this Project](#download-this-project)
    - [Creating a "steam" User Account](#creating-a-steam-user-account)
    - [Building the Docker image](#building-the-docker-image)
        - [Build arguments](#build-arguments)
    - [The directory structure](#the-directory-structure)
    - [Starting the server](#starting-the-server)
        - [Using only defaults](#using-only-defaults)
        - [Running multiple servers](#running-multiple-servers)
        - [Additional available arguments](#additional-available-arguments)
    - [Stop the server](#stop-the-server)
- [Quick & Dirty Setup](#quick--dirty-setup)

If you prefer a quick and easy setup without getting into the specifics, you can skip to the [Quick & Dirty Setup](#quick--dirty-setup) section after ensuring that all requirements are met.

## Requirements
- **A Linux host**: Required to run the Docker containers. [Learn how to set up a Linux server](https://ubuntu.com/tutorials/install-ubuntu-server).
- **Docker**: Needed to create and manage the server container. [Install Docker](https://docs.docker.com/get-docker/).
- **sudo permissions**: Necessary to execute Docker commands and manage system configurations. Typically, the user account created during the Linux operating system installation already has sudo permissions assigned. [Understanding sudo](https://www.sudo.ws/). [Set up sudo on Ubuntu](https://ubuntu.com/server/docs/installing-sudo).

## Files
Here are the important files in this project. The Dockerfile and script (.sh) files are designed to accept arguments, so modifications are usually unnecessary.

- [`create-steam-account.sh`](./create-steam-account.sh): Helps new Linux administrators create a Steam user account for the server.
- [`Dockerfile`](./Dockerfile): Contains instructions for Docker to build the image for the 7 Days to Die server.
- [`run-7d2d-server.sh`](./run-7d2d-server.sh): Starts the 7 Days to Die server within a Docker container.
- [`start_server.sh`](./start_server.sh): Starts the 7 Days to Die server inside the Docker container.
- [`serveradmin.xml`](./xml/serveradmin.xml): Default configuration file for server administrators.
- [`serverconfig.xml`](./xml/serverconfig.xml): Modified to set the `UserDataFolder` property to use the `/data` path within the Docker container.

## Installation and Use Steps

### Download this Project
Clone the repository to your home directory:
```sh
cd ~
git clone https://github.com/spafbi/7d2d-docker-server.git ~/7d2d-docker-server
cd ~/7d2d-docker-server
chmod +x ~/7d2d-docker-server/*.sh
```

### Creating a "steam" User Account
Running a Docker container as a non-root user is beneficial for security reasons. The container defaults to using the `steam` user with UID and GID 1001. The `create-steam-account.sh` script helps create a local `steam` user account for running the Docker container. This local `steam` user is not associated with any Steam account and is only for local security controls.

Run the `create-steam-account.sh` script:
```sh
~/7d2d-docker-server/create-steam-account.sh
```
This script will inform you if any build arguments
```
When this script runs, it will also inform you if any build arguments are required when creating the Docker image.

### Building the Docker image
Build the Docker image using the provided `Dockerfile`:
```sh
docker build -t 7d2d-server .
```
#### Build arguments
You can change the default user account, UID, and GID used in the Docker image by specifying build arguments. For example, to use a different user account with UID 2000 and GID 2000, you can run the following command:
```sh
docker build --build-arg USER=newuser --build-arg UID=2000 --build-arg GID=2000 -t 7d2d-server .
```
You can also run the docker container as your own user. Here's a command for building the container using your username, UID, and GID:
```sh
docker build --build-arg USER=$(whoami) --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t 7d2d-server .
```
> Note: If you do not use the default user of "steam", you will need to pass the user argument to the `run-7d2d-server.sh` script in that step. For more information, refer to the [Starting the Server](#starting-the-server) section.

### The directory structure
By default, the `run-7d2d-server.sh` script will create the following directory structure which looks like this:
```
/home/steam/game-servers/7d2d-server
├── data
│   ├── serverconfig.xml
│   └── Saves
│       └── serveradmin.xml
├── maps
└── mods
```
- The `data` directory on the host system is mapped to `/data` inside the Docker container, as specified by the `UserDataFolder` property in the `serverconfig.xml` file.
- Place any custom map/world directories you want the server to use in the `maps` directory on the host system. These directories will be mapped to `/7d2d/Data/Worlds` inside the container.
- Place any mod directories you want the server to use in the `mods` directory on the host system. These directories will be mapped to `/7d2d/Mods` inside the container.

The `data` directory is also where the `GeneratedWorlds` and `Twitch` subdirectories will be created by the server. These subdirectories are used for storing generated world data and Twitch integration settings, respectively.

You can use alternative locations on the host for the `data`, `maps`, and `mods` directories. Ensure you pass the appropriate options to the `run-7d2d-server.sh` script to specify these custom locations.

### Starting the server
#### Using only defaults
Start the 7 Days to Die server using the `run-7d2d-server.sh` script:
```sh
~/7d2d-docker-server/run-7d2d-server.sh
```
#### Running multple servers
To run multiple servers, use the `-n` flag to specify the server number and the `-c` flag to set the container name. For example:
```sh
~/7d2d-docker-server/run-7d2d-server.sh -n 2 -c my-other-7d2d-server
```
> Note: The server number determines the port assignments. The first server uses port 26900, the second server uses port 26903, and so on. Ensure each server has a unique Docker container name.
#### Additional available arguments
#### Additional available arguments
The `run-7d2d-server.sh` script accepts several arguments to customize the server setup:

- `-n <number>`: Specifies the server number. This determines the port assignments. The first server uses port 26900, the second server uses port 26903, and so on.
- `-c <container_name>`: Sets the Docker container name. Ensure each server has a unique container name when running multiple servers.
- `-u <username>`: Specifies the user to run the server as inside the Docker container. This should match the user created or specified during the Docker image build.
- `-g <group>`: Specifies the group to run the server as inside the Docker container. This should match the group created or specified during the Docker image build. If not provided, the primary group of the designated user will be used automatically.
- `-i <image>`: Specifies the Docker image to use. This option allows you to run different server images for each 7 Days to Die server container. For example, you can run different server versions such as 1.0 or Alpha 21.2.
- `-e <base_external_game_port>`: Sets the starting port for the game servers. This value, combined with the server number, determines the external ports exposed by the Docker container. The default value is 26900. For example, if the base port is 26900, the first server will use TCP/26900 and UDP/26900-26902, the second server will use TCP/26903 and UDP/26903-26905, and so on.
- `-w <base_external_web_port>`: Sets the starting port for the server's web and telnet listeners. This value, combined with the server number, determines the external ports exposed by the Docker container. The default value is 8080. For example, the first server will use ports 8080 (web) and 8081 (telnet), while the second server will use ports 8082 (web) and 8083 (telnet). If the web and telnet features are not enabled, the ports will still be opened but will not provide any service as there would be no listener to accept the requests.
- `-d <data_directory>`: Sets the host directory for the server's data. This directory is mapped to `/data` inside the Docker container.
- `-m <maps_directory>`: Sets the host directory for custom maps. This directory is mapped to `/7d2d/Data/Worlds` inside the Docker container.
- `-o <mods_directory>`: Sets the host directory for mods. This directory is mapped to `/7d2d/Mods` inside the Docker container.
- `-t <bool>`: Specifies whether to update the game server when the container starts. Set this to `true` to enable updates. If your Docker image is already up to date, you can leave this as `false`. The default value is `false`.
- `-h`: Displays help information for the script.

Example usage:
```sh
~/7d2d-docker-server/run-7d2d-server.sh -n 2 -c my-other-7d2d-server -u steam -d /custom/data -m /custom/maps -o /custom/mods
```
The above example will run the server in a container named "my-other-7d2d-server". It will expose the following ports:
- Game ports: TCP/26903 and UDP/26903-26905
- Web port: TCP/8082
- Telnet port: TCP/8083

The server's data, maps, and mods directories on the host will be located at:
- `/custom/data`
- `/custom/maps`
- `/custom/mods`
### Stop the server
To stop the server, you can use Docker commands or stop the container directly:
```sh
docker stop <container_name>
```
So, if your server is running in a container named `7d2d-server`, you would use the following command to stop it:
```sh
docker stop 7d2d-server
```

## Quick & Dirty Setup
Assuming you have a Linux host, Docker installed, and your user is a member of the docker group, follow these steps to quickly set up the server. (Ignore the "$ " at the beginning of each line - it represents your shell prompt)
```bash
$ cd ~
$ git clone https://github.com/spafbi/7d2d-docker-server.git ~/7d2d-docker-server
$ cd ~/7d2d-docker-server
$ chmod +x ~/7d2d-docker-server/*.sh
$ ~/7d2d-docker-server/create-steam-account.sh
$ docker build -t 7d2d-server .
$ ~/7d2d-docker-server/run-7d2d-server.sh
```
That's it! Follow these steps, and you'll have a 7 Days to Die server running in Docker in no time.