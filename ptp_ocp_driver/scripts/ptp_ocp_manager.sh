#!/bin/bash

# Enhanced PTP OCP Driver Manager
# Version 2.0.0
# 
# This script provides unified management of the Enhanced PTP OCP Driver
# with all reliability, performance, and monitoring features.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DRIVER_NAME="ptp_ocp_enhanced"
DRIVER_VERSION="2.0.0"
MODULE_PATH="/lib/modules/$(uname -r)/extra"
SYSFS_PATH="/sys/class/ptp_ocp_enhanced"
DEBUG_PATH="/sys/kernel/debug/ptp_ocp_enhanced"
LOG_FILE="/var/log/ptp_ocp_enhanced.log"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"
}

log_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check if driver is loaded
is_driver_loaded() {
    lsmod | grep -q "$DRIVER_NAME"
}

# Get driver version
get_driver_version() {
    if is_driver_loaded; then
        cat /proc/modules | grep "$DRIVER_NAME" | awk '{print $1 " version " $2}'
    else
        echo "Driver not loaded"
    fi
}

# Install driver with all enhancements
install_driver() {
    log_header "Installing Enhanced PTP OCP Driver v$DRIVER_VERSION"
    
    # Check if already installed
    if is_driver_loaded; then
        log_warning "Driver is already loaded"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            return 0
        fi
        remove_driver
    fi
    
    # Compile driver
    log_info "Compiling enhanced driver..."
    if ! make clean && make; then
        log_error "Failed to compile driver"
        exit 1
    fi
    
    # Install driver
    log_info "Installing driver module..."
    if ! make install; then
        log_error "Failed to install driver"
        exit 1
    fi
    
    # Load driver
    log_info "Loading driver module..."
    if ! modprobe "$DRIVER_NAME"; then
        log_error "Failed to load driver"
        exit 1
    fi
    
    # Wait for device to be ready
    sleep 2
    
    # Check if device is available
    if ! ls /dev/ptp* >/dev/null 2>&1; then
        log_error "No PTP devices found after loading driver"
        exit 1
    fi
    
    # Configure default settings
    configure_default_settings
    
    # Configure enhanced default settings
    configure_enhanced_defaults
    
    log_success "Enhanced PTP OCP Driver installed successfully"
    log_info "Driver version: $(get_driver_version)"
}

# Remove driver
remove_driver() {
    log_header "Removing Enhanced PTP OCP Driver"
    
    if ! is_driver_loaded; then
        log_info "Driver is not loaded"
        return 0
    fi
    
    # Unload driver
    log_info "Unloading driver module..."
    if ! modprobe -r "$DRIVER_NAME"; then
        log_error "Failed to unload driver"
        exit 1
    fi
    
    # Remove module files
    log_info "Removing module files..."
    rm -f "$MODULE_PATH/${DRIVER_NAME}.ko"
    depmod -a
    
    log_success "Enhanced PTP OCP Driver removed successfully"
}

# Configure default settings
configure_default_settings() {
    log_info "Configuring default settings..."
    
    # Enable performance mode
    echo "enabled" > /sys/class/ptp_ocp_enhanced/ocp0/performance_mode 2>/dev/null || true
    
    # Set cache timeout to 1ms
    echo "1000000" > /sys/class/ptp_ocp_enhanced/ocp0/cache_timeout 2>/dev/null || true
    
    # Enable watchdog
    echo "enabled" > /sys/class/ptp_ocp_enhanced/ocp0/watchdog_enabled 2>/dev/null || true
    
    # Enable auto-recovery
    echo "enabled" > /sys/class/ptp_ocp_enhanced/ocp0/auto_recovery 2>/dev/null || true
    
    log_success "Default settings configured"
}

# Show driver status
show_status() {
    log_header "Enhanced PTP OCP Driver Status"
    
    echo "Driver Information:"
    echo "  Name: $DRIVER_NAME"
    echo "  Version: $DRIVER_VERSION"
    echo "  Status: $(is_driver_loaded && echo "Loaded" || echo "Not loaded")"
    echo "  Module version: $(get_driver_version)"
    echo
    
    if is_driver_loaded; then
        echo "Device Information:"
        echo "  PTP devices: $(ls /dev/ptp* 2>/dev/null | wc -l)"
        echo "  Sysfs path: $SYSFS_PATH"
        echo "  Debug path: $DEBUG_PATH"
        echo
        
        echo "Performance Statistics:"
        if [ -f "$SYSFS_PATH/ocp0/performance_stats" ]; then
            cat "$SYSFS_PATH/ocp0/performance_stats"
        else
            echo "  Performance stats not available"
        fi
        echo
        
        echo "Health Status:"
        if [ -f "$SYSFS_PATH/ocp0/health_status" ]; then
            cat "$SYSFS_PATH/ocp0/health_status"
        else
            echo "  Health status not available"
        fi
        echo
        
        echo "Error Statistics:"
        if [ -f "$SYSFS_PATH/ocp0/error_count" ]; then
            cat "$SYSFS_PATH/ocp0/error_count"
        else
            echo "  Error stats not available"
        fi
        echo
        
        echo "Watchdog Status:"
        if [ -f "$SYSFS_PATH/ocp0/watchdog_status" ]; then
            cat "$SYSFS_PATH/ocp0/watchdog_status"
        else
            echo "  Watchdog status not available"
        fi
    fi
}

# Manage firmware
manage_firmware() {
    local action="$1"
    local firmware_file="$2"
    
    log_header "Firmware Management"
    
    case "$action" in
        "check")
            log_info "Checking firmware type..."
            if [ -f "/sys/class/ptp_ocp_enhanced/ocp0/firmware_type" ]; then
                cat "/sys/class/ptp_ocp_enhanced/ocp0/firmware_type"
            else
                log_warning "Firmware type not available"
            fi
            ;;
        "flash")
            if [ -z "$firmware_file" ]; then
                log_error "Firmware file not specified"
                exit 1
            fi
            if [ ! -f "$firmware_file" ]; then
                log_error "Firmware file not found: $firmware_file"
                exit 1
            fi
            log_info "Flashing firmware: $firmware_file"
            # Use existing flash script
            if [ -f "./scripts/firmware_tools/flash_programmer.sh" ]; then
                ./scripts/firmware_tools/flash_programmer.sh -f "$firmware_file"
            else
                log_error "Flash programmer not found"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown firmware action: $action"
            exit 1
            ;;
    esac
}

# Manage holdover
manage_holdover() {
    local action="$1"
    local mode="$2"
    
    log_header "Holdover Management"
    
    case "$action" in
        "status")
            log_info "Checking holdover status..."
            if [ -f "/sys/class/ptp_ocp_enhanced/ocp0/holdover" ]; then
                cat "/sys/class/ptp_ocp_enhanced/ocp0/holdover"
            else
                log_warning "Holdover status not available"
            fi
            ;;
        "set")
            if [ -z "$mode" ]; then
                log_error "Holdover mode not specified"
                exit 1
            fi
            log_info "Setting holdover mode: $mode"
            if [ -f "/sys/class/ptp_ocp_enhanced/ocp0/holdover" ]; then
                echo "$mode" > "/sys/class/ptp_ocp_enhanced/ocp0/holdover"
                log_success "Holdover mode set to $mode"
            else
                log_error "Holdover control not available"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown holdover action: $action"
            exit 1
            ;;
    esac
}

# Start monitoring dashboard
start_monitoring() {
    log_header "Starting Monitoring Dashboard"
    
    if ! is_driver_loaded; then
        log_error "Driver is not loaded"
        exit 1
    fi
    
    # Check if web interface is available
    if [ -f "./web_interface/dashboard/index.html" ]; then
        log_info "Starting web dashboard..."
        cd web_interface/dashboard
        python3 -m http.server 8080 &
        DASHBOARD_PID=$!
        echo $DASHBOARD_PID > /tmp/ptp_ocp_dashboard.pid
        log_success "Dashboard started at http://localhost:8080"
        log_info "Dashboard PID: $DASHBOARD_PID"
    else
        log_warning "Web dashboard not available, using console monitoring"
        console_monitoring
    fi
}

# Console monitoring
console_monitoring() {
    log_header "Console Monitoring"
    
    while true; do
        clear
        echo "Enhanced PTP OCP Driver - Real-time Monitoring"
        echo "Press Ctrl+C to exit"
        echo "=============================================="
        echo
        
        if [ -f "$SYSFS_PATH/ocp0/health_status" ]; then
            echo "Health Status:"
            cat "$SYSFS_PATH/ocp0/health_status"
            echo
        fi
        
        if [ -f "$SYSFS_PATH/ocp0/performance_stats" ]; then
            echo "Performance Stats:"
            cat "$SYSFS_PATH/ocp0/performance_stats"
            echo
        fi
        
        if [ -f "$SYSFS_PATH/ocp0/watchdog_status" ]; then
            echo "Watchdog Status:"
            cat "$SYSFS_PATH/ocp0/watchdog_status"
            echo
        fi
        
        echo "Last updated: $(date)"
        sleep 2
    done
}

# Stop monitoring
stop_monitoring() {
    log_header "Stopping Monitoring"
    
    if [ -f "/tmp/ptp_ocp_dashboard.pid" ]; then
        DASHBOARD_PID=$(cat /tmp/ptp_ocp_dashboard.pid)
        if kill -0 "$DASHBOARD_PID" 2>/dev/null; then
            kill "$DASHBOARD_PID"
            rm -f /tmp/ptp_ocp_dashboard.pid
            log_success "Dashboard stopped"
        else
            log_warning "Dashboard was not running"
        fi
    else
        log_info "No dashboard to stop"
    fi
}

# Run tests
run_tests() {
    log_header "Running Enhanced Driver Tests"
    
    if ! is_driver_loaded; then
        log_error "Driver is not loaded"
        exit 1
    fi
    
    # Check if test scripts are available
    if [ -d "./tests" ]; then
        log_info "Running test suite..."
        cd tests
        if [ -f "run_tests.sh" ]; then
            ./run_tests.sh
        else
            log_warning "Test runner not found"
        fi
        cd ..
    else
        log_warning "Test directory not found"
    fi
}

# Enhanced driver management functions
manage_enhanced_features() {
    local action="$1"
    local feature="$2"
    local value="$3"
    
    log_header "Enhanced Features Management"
    
    case "$action" in
        "enable")
            case "$feature" in
                "performance")
                    log_info "Enabling performance mode..."
                    echo "true" > "$SYSFS_PATH/ocp0/performance_mode" 2>/dev/null || {
                        log_error "Failed to enable performance mode"
                        exit 1
                    }
                    log_success "Performance mode enabled"
                    ;;
                "watchdog")
                    log_info "Enabling watchdog..."
                    echo "true" > "$SYSFS_PATH/ocp0/watchdog_enabled" 2>/dev/null || {
                        log_error "Failed to enable watchdog"
                        exit 1
                    }
                    log_success "Watchdog enabled"
                    ;;
                "auto_recovery")
                    log_info "Enabling auto-recovery..."
                    echo "true" > "$SYSFS_PATH/ocp0/auto_recovery" 2>/dev/null || {
                        log_error "Failed to enable auto-recovery"
                        exit 1
                    }
                    log_success "Auto-recovery enabled"
                    ;;
                *)
                    log_error "Unknown feature: $feature"
                    exit 1
                    ;;
            esac
            ;;
        "disable")
            case "$feature" in
                "performance")
                    log_info "Disabling performance mode..."
                    echo "false" > "$SYSFS_PATH/ocp0/performance_mode" 2>/dev/null || {
                        log_error "Failed to disable performance mode"
                        exit 1
                    }
                    log_success "Performance mode disabled"
                    ;;
                "watchdog")
                    log_info "Disabling watchdog..."
                    echo "false" > "$SYSFS_PATH/ocp0/watchdog_enabled" 2>/dev/null || {
                        log_error "Failed to disable watchdog"
                        exit 1
                    }
                    log_success "Watchdog disabled"
                    ;;
                "auto_recovery")
                    log_info "Disabling auto-recovery..."
                    echo "false" > "$SYSFS_PATH/ocp0/auto_recovery" 2>/dev/null || {
                        log_error "Failed to disable auto-recovery"
                        exit 1
                    }
                    log_success "Auto-recovery disabled"
                    ;;
                *)
                    log_error "Unknown feature: $feature"
                    exit 1
                    ;;
            esac
            ;;
        "status")
            log_info "Enhanced features status:"
            echo "Performance Mode:"
            if [ -f "$SYSFS_PATH/ocp0/performance_mode" ]; then
                cat "$SYSFS_PATH/ocp0/performance_mode"
            else
                echo "  Not available"
            fi
            echo "Watchdog:"
            if [ -f "$SYSFS_PATH/ocp0/watchdog_status" ]; then
                cat "$SYSFS_PATH/ocp0/watchdog_status"
            else
                echo "  Not available"
            fi
            echo "Auto-Recovery:"
            if [ -f "$SYSFS_PATH/ocp0/auto_recovery" ]; then
                cat "$SYSFS_PATH/ocp0/auto_recovery"
            else
                echo "  Not available"
            fi
            ;;
        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
}

# Show enhanced statistics
show_enhanced_stats() {
    log_header "Enhanced Driver Statistics"
    
    if ! is_driver_loaded; then
        log_error "Enhanced driver is not loaded"
        exit 1
    fi
    
    echo "Performance Statistics:"
    if [ -f "$SYSFS_PATH/ocp0/performance_stats" ]; then
        cat "$SYSFS_PATH/ocp0/performance_stats"
    else
        echo "  Performance stats not available"
    fi
    echo
    
    echo "Health Status:"
    if [ -f "$SYSFS_PATH/ocp0/health_status" ]; then
        cat "$SYSFS_PATH/ocp0/health_status"
    else
        echo "  Health status not available"
    fi
    echo
    
    echo "Error Statistics:"
    if [ -f "$SYSFS_PATH/ocp0/error_count" ]; then
        cat "$SYSFS_PATH/ocp0/error_count"
    else
        echo "  Error stats not available"
    fi
    echo
    
    echo "Watchdog Status:"
    if [ -f "$SYSFS_PATH/ocp0/watchdog_status" ]; then
        cat "$SYSFS_PATH/ocp0/watchdog_status"
    else
        echo "  Watchdog status not available"
    fi
}

# Configure default enhanced settings
configure_enhanced_defaults() {
    log_info "Configuring enhanced default settings..."
    
    # Enable watchdog by default
    if [ -f "$SYSFS_PATH/ocp0/watchdog_enabled" ]; then
        echo "true" > "$SYSFS_PATH/ocp0/watchdog_enabled"
        log_info "Watchdog enabled"
    fi
    
    # Enable auto-recovery by default
    if [ -f "$SYSFS_PATH/ocp0/auto_recovery" ]; then
        echo "true" > "$SYSFS_PATH/ocp0/auto_recovery"
        log_info "Auto-recovery enabled"
    fi
    
    # Disable performance mode by default (for stability)
    if [ -f "$SYSFS_PATH/ocp0/performance_mode" ]; then
        echo "false" > "$SYSFS_PATH/ocp0/performance_mode"
        log_info "Performance mode disabled (default)"
    fi
    
    log_success "Enhanced default settings configured"
}

# Show help
show_help() {
    echo "Enhanced PTP OCP Driver Manager v$DRIVER_VERSION"
    echo
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  install                 Install the enhanced driver"
    echo "  remove                  Remove the enhanced driver"
    echo "  status                  Show driver status and statistics"
    echo "  enhanced-stats          Show enhanced driver statistics"
    echo "  enhanced <action> <feature>  Manage enhanced features"
    echo "    enable performance    Enable performance mode"
    echo "    disable performance   Disable performance mode"
    echo "    enable watchdog       Enable watchdog"
    echo "    disable watchdog      Disable watchdog"
    echo "    enable auto_recovery  Enable auto-recovery"
    echo "    disable auto_recovery Disable auto-recovery"
    echo "    status                Show enhanced features status"
    echo "  firmware <action>       Manage firmware"
    echo "    check                 Check current firmware type"
    echo "    flash <file>          Flash new firmware"
    echo "  holdover <action>       Manage holdover mode"
    echo "    status                Check holdover status"
    echo "    set <mode>            Set holdover mode (0-3)"
    echo "  monitor                 Start monitoring dashboard"
    echo "  stop-monitor            Stop monitoring dashboard"
    echo "  test                    Run driver tests"
    echo "  help                    Show this help"
    echo
    echo "Examples:"
    echo "  $0 install              Install the enhanced driver"
    echo "  $0 status               Show current status"
    echo "  $0 firmware check       Check firmware type"
    echo "  $0 firmware flash firmware.bin"
    echo "  $0 holdover set 1       Set holdover mode 1"
    echo "  $0 monitor              Start monitoring dashboard"
    echo "  $0 test                 Run tests"
    echo
}

# Main function
main() {
    local command="$1"
    local arg1="$2"
    local arg2="$3"
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Check root privileges for most commands
    case "$command" in
        "install"|"remove"|"firmware"|"holdover"|"monitor"|"stop-monitor"|"test")
            check_root
            ;;
    esac
    
    case "$command" in
        "install")
            install_driver
            ;;
        "remove")
            remove_driver
            ;;
        "status")
            show_status
            ;;
        "enhanced-stats")
            show_enhanced_stats
            ;;
        "enhanced")
            manage_enhanced_features "$arg1" "$arg2" "$3"
            ;;
        "firmware")
            manage_firmware "$arg1" "$arg2"
            ;;
        "holdover")
            manage_holdover "$arg1" "$arg2"
            ;;
        "monitor")
            start_monitoring
            ;;
        "stop-monitor")
            stop_monitoring
            ;;
        "test")
            run_tests
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
