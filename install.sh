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

# Check if the script is running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with root (sudo) privileges."
    exit 1
fi

# Check if the system has Systemd
if ! systemctl --version > /dev/null 2>&1; then
    echo "This system does not have Systemd. The script cannot continue."
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install dependencies via various package managers
install_dependencies() {
    if command_exists apt-get; then
        echo "Installing dependencies via apt-get..."
        apt-get update
        apt-get install -y python3 python3-pip git
    elif command_exists dnf; then
        echo "Installing dependencies via dnf..."
        dnf install -y python3 python3-pip git
    elif command_exists yum; then
        echo "Installing dependencies via yum..."
        yum install -y python3 python3-pip git
    elif command_exists pacman; then
        echo "Installing dependencies via pacman..."
        pacman -Sy --noconfirm python python-pip git
    elif command_exists zypper; then
        echo "Installing dependencies via zypper..."
        zypper install -y python3 python3-pip git
    else
        echo "No compatible package manager found. Please install Python, pip, and Git manually."
        exit 1
    fi
}

# Install necessary dependencies
install_dependencies

# Create the directory for the program and copy the files
echo "Creating the directory for the program and copying the files..."

# Clone or update the Git repository
if [ -d "$INSTALL_DIR" ]; then
    echo "Directory $INSTALL_DIR already exists. Updating repository..."
    cd "$INSTALL_DIR"
    git pull
else
    echo "Cloning the repository from Git..."
    git clone "$GIT_REPO_URL" "$INSTALL_DIR"
fi

cp -r sensei_nakama/programs/sensei_nakama /usr/bin/

# Copy configuration files if the directory doesn't already exist
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Creating the configuration directory and copying the configuration file..."
    mkdir -p "$CONFIG_DIR"
    cp "$INSTALL_DIR/sensei_nakama.conf" "$CONFIG_DIR/"
else
    echo "Configuration directory $CONFIG_DIR already exists. Skipping configuration file copy."
fi

# Make the Python script executable
echo "Making Python script executable..."
chmod +x "$PYTHON_SCRIPT_PATH"

# Create the virtual environment and install dependencies
if [ ! -d "$VIRTUAL_ENV_PATH" ]; then
    echo "Creating the virtual environment and installing the dependencies..."
    python3 -m venv "$VIRTUAL_ENV_PATH"
fi

# Activate the virtual environment and install/update dependencies
echo "Activating virtual environment and installing/updating dependencies..."
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
echo "Checking the status of the service..."
sudo systemctl status "$SERVICE_NAME"

# Remove the cloned directory if necessary
echo "Removing the cloned Git repository directory..."

rm -rf sensei_nakama

echo "Installation complete."
