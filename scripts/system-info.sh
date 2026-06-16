#!/bin/bash

################################################################################
# system-info.sh
#
# Purpose: Display comprehensive system information including OS version,
#          CPU, memory, disk usage, uptime, and current user.
#
# Usage: ./system-info.sh
#
# Requirements:
#   - Bash 4.0+
#   - Common utilities: uname, lsb_release, nproc, free, df, uptime, whoami
#
# Author: Titan DevOps Platform
# Last Modified: 2026-06-16
################################################################################

set -o errexit
set -o pipefail

# Colors for output (optional)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

################################################################################
# Function: print_header
# Purpose: Print a formatted section header
# Arguments: $1 = header text
################################################################################
print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}${1}${NC}"
    echo -e "${BLUE}======================================${NC}"
}

################################################################################
# Function: display_os_info
# Purpose: Display operating system version and details
################################################################################
display_os_info() {
    print_header "Operating System Information"
    
    echo "Kernel Name:     $(uname -s)"
    echo "Kernel Release:  $(uname -r)"
    echo "Kernel Version:  $(uname -v)"
    echo "Hardware Arch:   $(uname -m)"
    
    # Try to get distribution info if available
    if command -v lsb_release &> /dev/null; then
        echo "Distribution:   $(lsb_release -d | cut -f2)"
        echo "Release:        $(lsb_release -r | cut -f2)"
        echo "Codename:       $(lsb_release -c | cut -f2)"
    fi
    echo
}

################################################################################
# Function: display_cpu_info
# Purpose: Display CPU information and count
################################################################################
display_cpu_info() {
    print_header "CPU Information"
    
    # Get number of CPUs
    local cpu_count
    cpu_count=$(nproc)
    echo "CPU Cores:       ${cpu_count}"
    
    # Get CPU model if available
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model
        cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
        if [[ -n "$cpu_model" ]]; then
            echo "CPU Model:       ${cpu_model}"
        fi
    fi
    
    # Get current CPU frequency if available
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_mhz
        cpu_mhz=$(grep -m1 "cpu MHz" /proc/cpuinfo | cut -d: -f2 | xargs)
        if [[ -n "$cpu_mhz" ]]; then
            echo "CPU Speed:       ${cpu_mhz} MHz"
        fi
    fi
    echo
}

################################################################################
# Function: display_memory_info
# Purpose: Display memory usage information
################################################################################
display_memory_info() {
    print_header "Memory Information"
    
    # Use free command to get memory info
    # Output format varies by system, parse carefully
    local mem_output
    mem_output=$(free -h | grep "Mem:")
    
    echo "Memory Total:    $(echo "$mem_output" | awk '{print $2}')"
    echo "Memory Used:     $(echo "$mem_output" | awk '{print $3}')"
    echo "Memory Free:     $(echo "$mem_output" | awk '{print $4}')"
    echo "Memory Available: $(echo "$mem_output" | awk '{print $7}')"
    
    # Calculate percentage used
    local mem_total_kb
    local mem_used_kb
    mem_total_kb=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
    mem_used_kb=$(grep "MemAvailable:" /proc/meminfo)
    
    if [[ -n "$mem_total_kb" ]]; then
        local mem_percent
        mem_percent=$(echo "scale=2; (($mem_total_kb - $(echo "$mem_used_kb" | awk '{print $2}'))) / $mem_total_kb * 100" | bc 2>/dev/null || echo "N/A")
        echo "Memory Usage %:  ${mem_percent}%"
    fi
    echo
}

################################################################################
# Function: display_disk_info
# Purpose: Display disk usage information for all mounted filesystems
################################################################################
display_disk_info() {
    print_header "Disk Usage Information"
    
    # Use df with human-readable output
    df -h | awk 'NR==1 {print; next} {printf "%-15s %-10s %-10s %-10s %-6s %s\n", $1, $2, $3, $4, $5, $6}'
    echo
}

################################################################################
# Function: display_uptime_info
# Purpose: Display system uptime information
################################################################################
display_uptime_info() {
    print_header "System Uptime"
    
    # Get uptime in seconds, calculate days/hours/minutes
    local uptime_seconds
    uptime_seconds=$(cut -d. -f1 /proc/uptime)
    
    local days=$((uptime_seconds / 86400))
    local hours=$(( (uptime_seconds % 86400) / 3600 ))
    local minutes=$(( (uptime_seconds % 3600) / 60 ))
    
    echo "Uptime:          ${days}d ${hours}h ${minutes}m"
    
    # Also show with uptime command
    echo "Command Output:  $(uptime | awk -F'up' '{print $2}' | cut -d',' -f1-3)"
    echo
}

################################################################################
# Function: display_user_info
# Purpose: Display current user information
################################################################################
display_user_info() {
    print_header "User Information"
    
    echo "Current User:    $(whoami)"
    echo "User ID (UID):   $(id -u)"
    echo "User Groups:     $(id -G | tr ' ' ',')"
    echo "Home Directory:  $HOME"
    echo
}

################################################################################
# Main Execution
################################################################################
main() {
    echo
    echo -e "${GREEN}Titan System Information Report${NC}"
    echo -e "${GREEN}Generated at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo
    
    display_os_info
    display_cpu_info
    display_memory_info
    display_disk_info
    display_uptime_info
    display_user_info
    
    echo -e "${GREEN}========== End of Report ==========${NC}"
    echo
}

# Execute main function
main "$@"
