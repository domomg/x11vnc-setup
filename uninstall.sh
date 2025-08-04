#!/bin/bash

# Enhanced x11vnc VNC Server Uninstall Script
# Author: Dom (@domomg)
# Supports: Ubuntu, Debian, Linux Mint, CentOS/RHEL/Rocky, Fedora, Arch Linux, openSUSE

set -euo pipefail  # Exit on error, undefined vars, pipe failures
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
VNC_CONFIG_DIR="/etc/x11vnc"
X11VNC_SERVICE="/etc/systemd/system/x11vnc.service"
AUTOCUTSEL_SERVICE="/etc/systemd/system/autocutsel.service"
LOG_FILE="/var/log/x11vnc.log"

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

stop_and_disable_service() {
    log "Stopping and disabling x11vnc service..."
    if systemctl is-active --quiet x11vnc.service 2>/dev/null; then
        if systemctl stop x11vnc.service; then
            success "x11vnc service stopped"
        else
            warning "Failed to stop x11vnc service"
        fi
    else
        info "x11vnc service is not running"
    fi
    if systemctl is-enabled --quiet x11vnc.service 2>/dev/null; then
        if systemctl disable x11vnc.service; then
            success "x11vnc service disabled"
        else
            warning "Failed to disable x11vnc service"
        fi
    else
        info "x11vnc service is not enabled"
    fi
}

stop_and_disable_autocutsel() {
    log "Stopping and disabling autocutsel service..."
    if systemctl is-active --quiet autocutsel.service 2>/dev/null; then
        if systemctl stop autocutsel.service; then
            success "autocutsel service stopped"
        else
            warning "Failed to stop autocutsel service"
        fi
    else
        info "autocutsel service is not running"
    fi

    if systemctl is-enabled --quiet autocutsel.service 2>/dev/null; then
        if systemctl disable autocutsel.service; then
            success "autocutsel service disabled"
        else
            warning "Failed to disable autocutsel service"
        fi
    else
        info "autocutsel service is not enabled"
    fi
}

remove_service_files() {
    log "Removing systemd service files..."
    for svc in "$X11VNC_SERVICE" "$AUTOCUTSEL_SERVICE"; do
        if [[ -f "$svc" ]]; then
            rm -f "$svc"
            success "Removed: $svc"
        else
            info "Service file not found: $svc"
        fi
    done
    systemctl daemon-reload
}


kill_running_processes() {
    log "Terminating any running x11vnc and autocutsel processes..."
    if pgrep -x x11vnc >/dev/null; then
        pkill -x x11vnc
        success "x11vnc processes terminated"
    else
        info "No running x11vnc processes found"
    fi
    if pgrep -x autocutsel >/dev/null; then
        pkill -x autocutsel
        success "autocutsel processes terminated"
    else
        info "No running autocutsel processes found"
    fi
}

remove_config_files() {
    log "Removing configuration files and directories..."
    if [[ -d "$VNC_CONFIG_DIR" ]]; then
        rm -rf "$VNC_CONFIG_DIR"
        success "Configuration directory removed: $VNC_CONFIG_DIR"
    else
        info "Configuration directory not found: $VNC_CONFIG_DIR"
    fi
    if [[ -f "$LOG_FILE" ]]; then
        rm -f "$LOG_FILE"
        success "Log file removed: $LOG_FILE"
    else
        info "Log file not found: $LOG_FILE"
    fi
}

remove_autocutsel_helper_script() {
    local helper_script="/usr/local/bin/start-autocutsel.sh"
    log "Removing autocutsel helper script..."
    if [[ -f "$helper_script" ]]; then
        rm -f "$helper_script"
        success "Removed autocutsel helper script: $helper_script"
    else
        info "Autocutsel helper script not found: $helper_script"
    fi
}

uninstall_packages() {
    log "Uninstalling x11vnc and autocutsel packages..."
    case $DISTRO in
        ubuntu|debian|linuxmint)
            if dpkg -l | grep -q "^ii.*x11vnc"; then
                apt remove -y x11vnc
                success "x11vnc package removed"
            else
                info "x11vnc package not installed"
            fi
            if dpkg -l | grep -q "^ii.*autocutsel"; then
                apt remove -y autocutsel
                success "autocutsel package removed"
            else
                info "autocutsel package not installed"
            fi
            apt autoremove -y
            ;;
        centos|rhel|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                if rpm -q x11vnc &>/dev/null; then
                    dnf remove -y x11vnc
                    success "x11vnc package removed"
                else
                    info "x11vnc package not installed"
                fi
                if rpm -q autocutsel &>/dev/null; then
                    dnf remove -y autocutsel
                    success "autocutsel package removed"
                else
                    info "autocutsel package not installed"
                fi
                dnf autoremove -y
            else
                if rpm -q x11vnc &>/dev/null; then
                    yum remove -y x11vnc
                    success "x11vnc package removed"
                else
                    info "x11vnc package not installed"
                fi
                if rpm -q autocutsel &>/dev/null; then
                    yum remove -y autocutsel
                    success "autocutsel package removed"
                else
                    info "autocutsel package not installed"
                fi
            fi
            ;;
        fedora)
            if rpm -q x11vnc &>/dev/null; then
                dnf remove -y x11vnc
                success "x11vnc package removed"
            else
                info "x11vnc package not installed"
            fi
            if rpm -q autocutsel &>/dev/null; then
                dnf remove -y autocutsel
                success "autocutsel package removed"
            else
                info "autocutsel package not installed"
            fi
            dnf autoremove -y
            ;;
        arch|manjaro)
            if pacman -Qi x11vnc &>/dev/null; then
                pacman -Rs --noconfirm x11vnc
                success "x11vnc package removed"
            else
                info "x11vnc package not installed"
            fi
            if pacman -Qi autocutsel &>/dev/null; then
                pacman -Rs --noconfirm autocutsel
                success "autocutsel package removed"
            else
                info "autocutsel package not installed"
            fi
            ;;
        opensuse*|sles)
            if rpm -q x11vnc &>/dev/null; then
                zypper remove -y x11vnc
                success "x11vnc package removed"
            else
                info "x11vnc package not installed"
            fi
            if rpm -q autocutsel &>/dev/null; then
                zypper remove -y autocutsel
                success "autocutsel package removed"
            else
                info "autocutsel package not installed"
            fi
            ;;
        *)
            warning "Unsupported distribution: $DISTRO"
            info "Please manually remove x11vnc and autocutsel packages"
            ;;
    esac
}

show_firewall_info() {
    echo -e "${YELLOW}"
    echo "FIREWALL CLEANUP:"
    echo "If you (optionally) opened VNC ports in your firewall, you may want to close them:"
    echo ""
    echo "For UFW (Ubuntu/Debian):"
    echo "  sudo ufw delete allow 5900/tcp"
    echo "  (Replace 5900 with your custom port if different)"
    echo ""
    echo "For firewalld (CentOS/RHEL/Fedora):"
    echo "  sudo firewall-cmd --permanent --remove-port=5900/tcp"
    echo "  sudo firewall-cmd --reload"
    echo ""
    echo "For iptables:"
    echo "  sudo iptables -D INPUT -p tcp --dport 5900 -j ACCEPT"
    echo -e "${NC}"
}

confirm_uninstall() {
    echo -e "${YELLOW}"
    echo "WARNING: This will completely remove x11vnc VNC server and all its configuration!"
    echo "The following actions will be performed:"
    echo "  - Stop and disable x11vnc systemd service"
    echo "  - Remove systemd service file"
    echo "  - Kill any running x11vnc and autocutsel processes"
    echo "  - Remove configuration directory: $VNC_CONFIG_DIR"
    echo "  - Remove log file: $LOG_FILE"
    echo "  - Uninstall x11vnc and autocutsel packages"
    echo -e "${NC}"
    while true; do
        read -r -p "Are you sure you want to proceed? (yes/no): " confirm
        echo -e "${NC}"
        case "$confirm" in
            yes)
                break
                ;;
            no)
                info "Uninstall cancelled by user"
                exit 0
                ;;
            *)
                warning "Please type the full word 'yes' or 'no'"
                echo -e "${RED}"
                ;;
        esac
    done
}

main() {
    echo -e "${YELLOW}"
    echo "=============================================="
    echo "  Enhanced x11vnc VNC Server Uninstall Script"
    echo "  Multi-distribution support"
    echo "  Author: Dom (@domomg on GitHub)"
    echo "=============================================="
    echo -e "${NC}"
    info "Starting x11vnc uninstallation..."
    check_root
    detect_distro
    confirm_uninstall
    stop_and_disable_service
    stop_and_disable_autocutsel
    remove_service_files
    remove_autocutsel_helper_script
    kill_running_processes
    remove_config_files
    uninstall_packages
    show_firewall_info
    echo -e "${GREEN}"
    echo "==============================================="
    echo "x11vnc VNC Server Uninstall Complete!"
    echo "==============================================="
    echo ""
    echo "All x11vnc components have been removed:"
    echo " -> Systemd service stopped and disabled"
    echo " -> Service file removed"
    echo " -> Running processes terminated"
    echo " -> Configuration files removed"
    echo " -> Packages uninstalled"
    echo ""
    echo "The system has been cleaned up successfully."
    echo -e "${NC}"
    success "Uninstallation completed successfully!"
}
main "$@"
