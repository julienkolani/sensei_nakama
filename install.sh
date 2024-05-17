#!/bin/bash

# Variables
GIT_REPO_URL="https://github.com/julienkolani/sensei_nakama.git"
INSTALL_DIR=/usr/bin/sensei_nakama
CONFIG_DIR=/etc/sensei_nakama
PYTHON_SCRIPT_PATH="$INSTALL_DIR/main.py"
VIRTUAL_ENV_PATH="$INSTALL_DIR/venv"
SERVICE_NAME="sensei_nakama"
LOG_IDENTIFIER="sensei_nakama"
PYTHON_MODULES="'configparser==7.0.0' 'pip==24.0' 'rocket-python==1.3.4'"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
COLOR_OFF='\033[0m'

# Check if the script is running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}This script must be run with root (sudo) privileges.${COLOR_OFF}"
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install dependencies via various package managers
install_dependencies() {
    if command_exists apt-get; then
        echo "${GREEN}Installing dependencies via apt-get...${COLOR_OFF}"
        apt-get update
        apt-get install -y python3 python3-pip git
    elif command_exists dnf; then
        echo "${GREEN}Installing dependencies via dnf...${COLOR_OFF}"
        dnf install -y python3 python3-pip git
    elif command_exists yum; then
        echo "${GREEN}Installing dependencies via yum...${COLOR_OFF}"
        yum install -y python3 python3-pip git
    elif command_exists pacman; then
        echo "${GREEN}Installing dependencies via pacman...${COLOR_OFF}"
        pacman -Sy --noconfirm python python-pip git
    elif command_exists zypper; then
        echo "${GREEN}Installing dependencies via zypper...${COLOR_OFF}"
        zypper install -y python3 python3-pip git
    else
        echo "${RED}No compatible package manager found. Please install Python, pip, and Git manually.${COLOR_OFF}"
        exit 1
    fi
}

# Install necessary dependencies
install_dependencies

# Create the directory for the program and copy the files
echo "Creating the directory for the program and copying the files..."

# Clone or update the Git repository
if [ -d "$INSTALL_DIR" ]; then
    echo "${YELLOW}Directory $INSTALL_DIR already exists. Updating repository...${COLOR_OFF}"
    cd "$INSTALL_DIR"
    git pull
else
    echo "${GREEN}Cloning the repository from Git...${COLOR_OFF}"
    git clone "$GIT_REPO_URL" "$INSTALL_DIR"
fi

cp -r sensei_nakama/programs/sensei_nakama /usr/bin/

# Copy configuration files if the directory doesn't already exist
if [ ! -d "$CONFIG_DIR" ]; then
    echo "${GREEN}Creating the configuration directory and copying the configuration file...${COLOR_OFF}"
    mkdir -p "$CONFIG_DIR"
    cp "$INSTALL_DIR/sensei_nakama.conf" "$CONFIG_DIR/"
else
    echo "${YELLOW}Configuration directory $CONFIG_DIR already exists. Skipping configuration file copy.${COLOR_OFF}"
fi

# Make the Python script executable
echo "${GREEN}Making Python script executable...${COLOR_OFF}"
chmod +x "$PYTHON_SCRIPT_PATH"

# Create the virtual environment and install dependencies
if [ ! -d "$VIRTUAL_ENV_PATH" ]; then
    echo "${GREEN}Creating the virtual environment and installing the dependencies...${COLOR_OFF}"
    python3 -m venv "$VIRTUAL_ENV_PATH"
fi

# Activate the virtual environment and install/update dependencies
echo "${GREEN}Activating virtual environment and installing/updating dependencies...${COLOR_OFF}"
source "$VIRTUAL_ENV_PATH/bin/activate"
pip install --upgrade pip
for module in $PYTHON_MODULES; do
    pip install "$module"
done
deactivate

# Create Systemd service file
echo "Creating Systemd service file..."
cat << EOF | sudo tee /etc/systemd/system/"$SERVICE_NAME".service
[Unit]
Description=$SERVICE_NAME Service
After=network.target

[Service]
ExecStart=$VIRTUAL_ENV_PATH/bin/python $PYTHON_SCRIPT_PATH
Restart=always
User=root
Group=root
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$LOG_IDENTIFIER

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
echo "Enabling and starting the service..."
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

# Check the status of the service
echo "${GREEN}Checking the status of the service...${COLOR_OFF}"
sudo systemctl status "$SERVICE_NAME"

# Remove the cloned directory if necessary
echo "${GREEN}Removing the cloned Git repository directory...${COLOR_OFF}"

rm -rf sensei_nakama

echo "${GREEN}Installation complete.${COLOR_OFF}"
