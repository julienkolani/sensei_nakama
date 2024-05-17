#!/bin/bash

# Variables
GIT_REPO_URL="https://github.com/julienkolani/sensei_nakama.git"
PYTHON_SCRIPT_PATH="/usr/bin/sensei_nakama/main.py"
VIRTUAL_ENV_PATH="/usr/bin/sensei_nakama/venv"
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

# Check if Python is installed, and if not, install it
if ! command -v python3 &> /dev/null; then
    echo "Python3 is not installed. Installing Python3..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip
fi

# Clone the repository from Git
echo "Cloning the repository from Git..."
git clone "$GIT_REPO_URL"
cd sensei_nakama

# Create the directory for the program and copy the files
echo "Creating the directory for the program and copying the files..."
mkdir -p /usr/bin/sensei_nakama
cp -r sensei_nakama/programs/sensei_nakama /usr/bin/

# Create the configuration directory and copy the configuration file
echo "Creating the configuration directory and copying the configuration file..."
mkdir -p /etc/sensei_nakama
cp sensei_nakama/programs/sensei_nakama/sensei_nakama.conf /etc/sensei_nakama/

# Make Python script executable
echo "Making Python script executable..."
chmod +x "$PYTHON_SCRIPT_PATH"

# Create the virtual environment and install the dependencies
echo "Creating the virtual environment and installing the dependencies..."
python3 -m venv "$VIRTUAL_ENV_PATH"
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

# Remove the cloned Git repository directory
echo "Removing the cloned Git repository directory..."
cd ..
rm -rf sensei_nakama
