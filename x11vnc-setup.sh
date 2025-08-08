#!/bin/bash

# Enhanced x11vnc VNC Server Setup Script
# Author: Dom (@domomg on Github)
# Supports: Ubuntu, Debian, Linux Mint, CentOS/RHEL/Rocky, Fedora, Arch Linux, openSUSE

set -euo pipefail  # Exit on error, undefined vars, pipe failures
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
VNC_CONFIG_DIR="/etc/x11vnc"
VNC_PASSWORD_FILE="$VNC_CONFIG_DIR/vncpwd"
SERVICE_FILE="/etc/systemd/system/x11vnc.service"
VNC_PORT=5900
VNC_USER=""
BIND_FLAG=""
BIND_TYPE=""

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}
error() {
    echo -e "${RED}[ERROR] ✗${NC} $1" >&2
}
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
success() {
    echo -e "${GREEN}[SUCCESS] ✓${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=$ID
    else
        error "Cannot detect Linux distribution"
        exit 1
    fi
    info "Detected distribution: $PRETTY_NAME"
}

install_x11vnc() {
    log "Installing x11vnc and autocutsel..."
    case $DISTRO in
        ubuntu|debian|linuxmint)
            apt update
            apt install -y x11vnc autocutsel
            ;;
        centos|rhel|rocky|almalinux)
            # Enable EPEL for CentOS/RHEL
            if command -v dnf &> /dev/null; then
                dnf install -y epel-release
                dnf install -y x11vnc autocutsel
            else
                yum install -y epel-release
                yum install -y x11vnc autocutsel
            fi
            ;;
        fedora)
            dnf install -y x11vnc autocutsel
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm x11vnc autocutsel
            ;;
        opensuse*|sles)
            zypper install -y x11vnc autocutsel
            ;;
        *)
            error "Unsupported distribution: $DISTRO"
            info "Please install x11vnc manually and re-run this script"
            exit 1
            ;;
    esac
    if ! command -v x11vnc &> /dev/null; then
        error "x11vnc installation failed"
        exit 1
    fi
    success "x11vnc installed successfully"
}

setup_config_dir() {
    log "Setting up configuration directory..."
    if [[ ! -d "$VNC_CONFIG_DIR" ]]; then
        mkdir -p "$VNC_CONFIG_DIR"
        chmod 755 "$VNC_CONFIG_DIR"
    fi
}

setup_password() {
    log "Setting up VNC password..."
    echo -e "${YELLOW}"
    echo "VNC Password Setup:"
    echo "- Password must be 8 characters or less (VNC limitation)"
    echo "- Choose a strong password for security"
    echo "- You'll be prompted to confirm the password"
    echo -e "${NC}"
    [[ -f "$VNC_PASSWORD_FILE" ]] && rm -f "$VNC_PASSWORD_FILE"
    if ! x11vnc -storepasswd "$VNC_PASSWORD_FILE"; then
        error "Failed to set VNC password"
        exit 1
    fi
    chmod 600 "$VNC_PASSWORD_FILE"
    success "VNC password configured successfully"
}

get_vnc_user() {
    echo -e "${BLUE}"
    read -r -p "Enter username to run VNC as (leave empty and press Enter for root): " VNC_USER
    echo -e "${NC}"
    if [[ -n "$VNC_USER" ]]; then
        if ! id "$VNC_USER" &>/dev/null; then
            error "User '$VNC_USER' does not exist"
            exit 1
        fi
        chown -R "$VNC_USER:$VNC_USER" "$VNC_CONFIG_DIR"
        info "VNC will run as user: $VNC_USER"
    else
        VNC_USER="root"
        warning "VNC will run as root (not recommended for security)"
    fi
}

configure_port() {
    echo -e "${BLUE}"
    read -r -p "Enter VNC port (leave empty and press Enter for default 5900): " custom_port
    echo -e "${NC}"
    if [[ -n "$custom_port" ]]; then
        if [[ "$custom_port" =~ ^[0-9]+$ ]] && [[ "$custom_port" -ge 1024 ]] && [[ "$custom_port" -le 65535 ]]; then
            VNC_PORT="$custom_port"
            info "VNC port set to: $VNC_PORT"
        else
            warning "Invalid port. Using default 5900"
            VNC_PORT=5900
        fi
    else
        info "Using default VNC port: 5900"
    fi
}

configure_bind_interface() {
    echo -e "${BLUE}"
    echo "NETWORK SECURITY SETTING:"
    echo "Choose how the VNC server should bind to the network:"
    echo ""
    echo "  [1] All interfaces (default) - accessible over LAN/internet"
    echo "  [2] Localhost only - for use with secure SSH tunneling"
    echo ""
    echo -e "${NC}"
    while true; do
        read -r -p "Bind VNC server to [1/all] or [2/localhost]? (default: 1): " bind_choice
        case "$bind_choice" in
            "" | "1")
                BIND_TYPE="all"
                BIND_FLAG=""
                break
                ;;
            "2")
                BIND_TYPE="localhost"
                BIND_FLAG="-localhost"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

create_systemd_service() {
    log "Creating systemd service..."
    local after_target="graphical.target"
    local wanted_by="graphical.target"
    local exec_start="/usr/bin/x11vnc"
    exec_start+=" -auth guess"
    exec_start+=" -forever"
    exec_start+=" -noxdamage"
    exec_start+=" -repeat"
    exec_start+=" -rfbauth $VNC_PASSWORD_FILE"
    exec_start+=" -rfbport $VNC_PORT"
    exec_start+=" -shared"
    exec_start+=" $BIND_FLAG"
    exec_start+=" -display :0"
    exec_start+=" -bg"
    exec_start+=" -o /var/log/x11vnc.log"
    exec_start+=" -noprimary"
    exec_start+=" -alwaysshared"
    cat > "$SERVICE_FILE" << EOL
[Unit]
Description=x11vnc VNC Server
Documentation=man:x11vnc(1)
After=$after_target
Wants=$after_target

[Service]
Type=forking
User=$VNC_USER
Group=$VNC_USER
ExecStart=$exec_start
ExecStop=/usr/bin/pkill -f x11vnc
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=read-only
ProtectSystem=strict
ReadWritePaths=/var/log

[Install]
WantedBy=$wanted_by
EOL
    chmod 644 "$SERVICE_FILE"
    success "Systemd service created"
}

create_autocutsel_helper_script() {
    log "Creating autocutsel helper script to run as active user..."
cat > /usr/local/bin/start-autocutsel.sh << 'EOF'
#!/bin/bash
# Find the active graphical user session
user=$(loginctl list-sessions --no-legend | awk '{print $1}' | while read session; do
state=$(loginctl show-session "$session" -p Active --value)
if [[ "$state" == "yes" ]]; then
    loginctl show-session "$session" -p Name --value
    break
fi
done)
if [[ -z "$user" ]]; then
    echo "No active graphical user found" >&2
    exit 1
fi
# Set DISPLAY and XAUTHORITY for the user
display=:0
xauth="/home/$user/.Xauthority"
if [[ ! -f "$xauth" ]]; then
    echo "Xauthority file not found at $xauth" >&2
    exit 1
fi
exec sudo -u "$user" DISPLAY=$display XAUTHORITY=$xauth /usr/bin/autocutsel
EOF
    chmod +x /usr/local/bin/start-autocutsel.sh
    success "Autocutsel helper script created at /usr/local/bin/start-autocutsel.sh"
    }

create_autocutsel_service() {
    log "Creating autocutsel systemd service..."
    local service_path="/etc/systemd/system/autocutsel.service"
    cat > "$service_path" << EOL
[Unit]
Description=autocutsel clipboard sync
After=graphical.target
Wants=graphical.target

[Service]
Type=simple
ExecStart=/usr/local/bin/start-autocutsel.sh
Restart=always
RestartSec=3

[Install]
WantedBy=graphical.target
EOL
    chmod 644 "$service_path"
    success "autocutsel systemd service created"
}

enable_service() {
    log "Enabling and starting x11vnc service..."
    systemctl daemon-reload
    if systemctl enable x11vnc.service; then
        success "Service enabled successfully"
    else
        error "Failed to enable service"
        exit 1
    fi
    if systemctl start x11vnc.service; then
        success "Service started successfully"
    else
        error "Failed to start service"
        info "Check service status with: systemctl status x11vnc.service"
        info "Check logs with: journalctl -u x11vnc.service -f"
        exit 1
    fi

    log "Enabling and starting autocutsel service..."
    systemctl daemon-reload
    if systemctl enable autocutsel.service; then
        success "Service enabled successfully"
    else
        error "Failed to enable service"
        exit 1
    fi
    if systemctl start autocutsel.service; then
        success "Service started successfully"
    else
        error "Failed to start service"
        info "Check service status with: systemctl status autocutsel.service"
        info "Check logs with: journalctl -u autocutsel.service -f"
        exit 1
    fi

}

check_service_status() {
    log "Checking service status..."
    if systemctl is-active --quiet x11vnc.service; then
        success "x11vnc service is running"
        if ss -tlnp | grep -q ":$VNC_PORT "; then
            success "VNC server is listening on port $VNC_PORT"
        else
            warning "VNC server may not be listening on port $VNC_PORT"
        fi
    else
        error "x11vnc service is not running"
        info "Check status with: systemctl status x11vnc.service"
    fi
}

show_firewall_info() {
    echo -e "${YELLOW}"
    echo "FIREWALL CONFIGURATION:"
    echo "You may need to open port $VNC_PORT in your firewall:"
    echo ""
    echo "For UFW (Ubuntu/Debian):"
    echo "  sudo ufw allow $VNC_PORT/tcp"
    echo ""
    echo "For firewalld (CentOS/RHEL/Fedora):"
    echo "  sudo firewall-cmd --permanent --add-port=$VNC_PORT/tcp"
    echo "  sudo firewall-cmd --reload"
    echo ""
    echo "For iptables:"
    echo "  sudo iptables -A INPUT -p tcp --dport $VNC_PORT -j ACCEPT"
    echo -e "${NC}"
}

show_connection_info() {
    local ip_address
    ip_address=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}"
    echo "==============================================="
    echo "x11vnc VNC Server Setup Complete!"
    echo "==============================================="
    echo ""
    echo "Connection Information:"
    echo "  Server IP: $ip_address"
    echo "  VNC Port: $VNC_PORT"
    echo "  Running as: $VNC_USER"
    echo ""
    echo "Connect using a VNC client:"
    echo "  Address: $ip_address:$VNC_PORT"
    echo ""
    echo "Service Management:"
    echo "  Status: systemctl status x11vnc.service"
    echo "  Stop:   systemctl stop x11vnc.service"
    echo "  Start:  systemctl start x11vnc.service"
    echo "  Logs:   journalctl -u x11vnc.service -f"
    echo ""
    echo "Configuration files:"
    echo "  Service: $SERVICE_FILE"
    echo "  Password: $VNC_PASSWORD_FILE"
    echo "  Log: /var/log/x11vnc.log"
    if [[ "$BIND_TYPE" == "localhost" ]]; then
        echo ""
        echo "Since the server is listening only on localhost, use SSH tunneling to access it remotely:"
        echo ""
        echo "  ssh -L <local-port>:localhost:$VNC_PORT $VNC_USER@<your-server-ip>"
        echo "  Example: ssh -L 5900:localhost:$VNC_PORT $VNC_USER@$ip_address"
        echo ""
        echo "Then connect your VNC client to localhost:<local-port> (e.g., localhost:5900)"
    fi
    echo -e "${NC}"
}

cleanup() {
    if [[ -f "$SERVICE_FILE" ]]; then
        systemctl stop x11vnc.service 2>/dev/null || true
        systemctl disable x11vnc.service 2>/dev/null || true
        rm -f "$SERVICE_FILE"
    fi
    [[ -d "$VNC_CONFIG_DIR" ]] && rm -rf "$VNC_CONFIG_DIR"
        error "Installation interrupted and cleaned up"
    exit 1
}

main() {
    trap cleanup INT TERM
    echo -e "${YELLOW}"
    echo "=============================================="
    echo "  Enhanced x11vnc VNC Server Setup Script"
    echo "  Multi-distribution support with security"
    echo "  Author: Dom (@domomg on GitHub)"
    echo "=============================================="
    echo -e "${NC}"
    info "Starting x11vnc installation and configuration..."
    check_root
    detect_distro
    echo -e "${BLUE}"
    read -r -p "Press Enter to continue with installation..." </dev/tty
    echo -e "${NC}"
    install_x11vnc
    setup_config_dir
    get_vnc_user
    configure_port
    configure_bind_interface
    setup_password
    create_systemd_service
    create_autocutsel_helper_script
    create_autocutsel_service
    enable_service
    check_service_status
    show_firewall_info
    show_connection_info
    success "Installation completed successfully!"
}
main "$@"
