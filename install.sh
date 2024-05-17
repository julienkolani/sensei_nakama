#!/bin/bash

# Variables
GIT_REPO_URL="https://github.com/julienkolani/sensei_nakama.git"
INSTALL_DIR="/usr/bin/sensei_nakama"
CONFIG_DIR="/etc/sensei_nakama"
PYTHON_SCRIPT_PATH="$INSTALL_DIR/main.py"
VIRTUAL_ENV_PATH="$INSTALL_DIR/venv"
SERVICE_NAME="sensei_nakama"
LOG_IDENTIFIER="sensei_nakama"
PYTHON_MODULES="'configparser==7.0.0' 'pip==24.0' 'rocket-python==1.3.4'"

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if the script is running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with root (sudo) privileges."
    exit 1
fi

# Detect if the system uses systemd or service
if command_exists systemctl; then
    SERVICE_MANAGER="systemd"
elif command_exists service; then
    SERVICE_MANAGER="service"
else
    echo "Neither systemd nor service detected. The script cannot continue."
    exit 1
fi

# Check if Python is installed, and if not, install it
if ! command_exists python3; then
    echo "Python3 is not installed. Installing Python3..."
    apt-get update
    apt-get install -y python3 python3-pip
fi

# Check if Git is installed, and if not, install it
if ! command_exists git; then
    echo "Git is not installed. Installing Git..."
    apt-get install -y git
fi

# Clone the repository from Git
echo "Cloning the repository from Git..."
git clone "$GIT_REPO_URL"
cd sensei_nakama

# Create the directory for the program and copy the files
echo "Creating the directory for the program and copying the files..."
mkdir -p "$INSTALL_DIR"
cp -r programs/sensei_nakama/* "$INSTALL_DIR/"

# Create the configuration directory and copy the configuration file
echo "Creating the configuration directory and copying the configuration file..."
mkdir -p "$CONFIG_DIR"
cp programs/sensei_nakama/sensei_nakama.conf "$CONFIG_DIR/"

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

# Create Systemd service file if using systemd
if [ "$SERVICE_MANAGER" = "systemd" ]; then
    echo "Creating Systemd service file..."
    cat << EOF | tee /etc/systemd/system/"$SERVICE_NAME".service
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

    # Enable and start the service using systemd
    echo "Enabling and starting the service with systemd..."
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    echo "Checking the status of the service..."
    systemctl status "$SERVICE_NAME"

# Create init.d script if using service
elif [ "$SERVICE_MANAGER" = "service" ]; then
    echo "Creating init.d service script..."
    cat << EOF | tee /etc/init.d/"$SERVICE_NAME"
#!/bin/sh
### BEGIN INIT INFO
# Provides:          $SERVICE_NAME
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

DIR=$INSTALL_DIR
DAEMON=$VIRTUAL_ENV_PATH/bin/python
DAEMON_NAME=$SERVICE_NAME

DAEMON_OPTS="$PYTHON_SCRIPT_PATH"

# Root only
[ \$UID -eq 0 ] || exit 1

. /lib/lsb/init-functions

do_start () {
    log_daemon_msg "Starting system $DAEMON_NAME daemon"
    start-stop-daemon --start --background --exec \$DAEMON -- \$DAEMON_OPTS
    log_end_msg \$?
}
do_stop () {
    log_daemon_msg "Stopping system $DAEMON_NAME daemon"
    start-stop-daemon --stop --exec \$DAEMON
    log_end_msg \$?
}

case "\$1" in
    start|stop)
        do_\$1
        ;;
    restart|reload|force-reload)
        do_stop
        do_start
        ;;
    status)
        status_of_proc "\$DAEMON" "\$DAEMON_NAME" && exit 0 || exit \$?
        ;;
    *)
        echo "Usage: /etc/init.d/\$DAEMON_NAME {start|stop|restart|status}"
        exit 1
        ;;
esac
exit 0
EOF

    # Make the init.d script executable
    chmod +x /etc/init.d/"$SERVICE_NAME"
    update-rc.d "$SERVICE_NAME" defaults

    # Start the service using init.d
    echo "Starting the service with init.d..."
    service "$SERVICE_NAME" start
    echo "Checking the status of the service..."
    service "$SERVICE_NAME" status
fi

# Remove the cloned Git repository directory
echo "Removing the cloned Git repository directory..."
cd ..
rm -rf sensei_nakama

echo "Installation complete."
