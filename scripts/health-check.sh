#!/bin/bash

################################################################################
# health-check.sh
#
# Purpose: Monitor system health and alert if CPU, memory, or disk usage
#          exceeds defined thresholds (default: 80%).
#
# Usage: ./health-check.sh [--cpu-threshold N] [--mem-threshold N] [--disk-threshold N]
#
# Examples:
#   ./health-check.sh
#   ./health-check.sh --cpu-threshold 75 --mem-threshold 85
#
# Requirements:
#   - Bash 4.0+
#   - Common utilities: top, free, df, bc
#
# Author: Titan DevOps Platform
# Last Modified: 2026-06-16
################################################################################

set -o errexit
set -o pipefail

# Default thresholds (as percentages)
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=80

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

################################################################################
# Function: print_usage
# Purpose: Display usage information
################################################################################
print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Monitor system health metrics and display warnings for exceeded thresholds.

OPTIONS:
    --cpu-threshold N       CPU usage threshold percentage (default: 80)
    --mem-threshold N       Memory usage threshold percentage (default: 80)
    --disk-threshold N      Disk usage threshold percentage (default: 80)
    --help                  Display this help message

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --cpu-threshold 75 --mem-threshold 85 --disk-threshold 90

EOF
}

################################################################################
# Function: parse_arguments
# Purpose: Parse command-line arguments
################################################################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cpu-threshold)
                CPU_THRESHOLD="$2"
                shift 2
                ;;
            --mem-threshold)
                MEM_THRESHOLD="$2"
                shift 2
                ;;
            --disk-threshold)
                DISK_THRESHOLD="$2"
                shift 2
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                print_usage
                exit 1
                ;;
        esac
    done
}

################################################################################
# Function: validate_threshold
# Purpose: Validate that threshold is a number between 0 and 100
# Arguments: $1 = threshold value, $2 = threshold name
################################################################################
validate_threshold() {
    local threshold="$1"
    local name="$2"
    
    if ! [[ "$threshold" =~ ^[0-9]+$ ]] || [[ "$threshold" -lt 0 ]] || [[ "$threshold" -gt 100 ]]; then
        echo "Error: $name must be a number between 0 and 100" >&2
        exit 1
    fi
}

################################################################################
# Function: check_cpu_usage
# Purpose: Check CPU usage and alert if threshold exceeded
################################################################################
check_cpu_usage() {
    local cpu_usage
    
    # Get CPU usage as percentage (average across all cores)
    # Use top in batch mode to get CPU usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | cut -d. -f1)
    
    echo -n "CPU Usage:    ${cpu_usage}%"
    
    if [[ "$cpu_usage" -ge "$CPU_THRESHOLD" ]]; then
        echo -e " ${RED}[WARNING - Threshold: ${CPU_THRESHOLD}%]${NC}"
        return 1
    else
        echo -e " ${GREEN}[OK]${NC}"
        return 0
    fi
}

################################################################################
# Function: check_memory_usage
# Purpose: Check memory usage and alert if threshold exceeded
################################################################################
check_memory_usage() {
    local mem_total
    local mem_available
    local mem_used
    local mem_percent
    
    # Get memory information from /proc/meminfo
    mem_total=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
    mem_available=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')
    mem_used=$((mem_total - mem_available))
    mem_percent=$((mem_used * 100 / mem_total))
    
    echo -n "Memory Usage: ${mem_percent}%"
    
    if [[ "$mem_percent" -ge "$MEM_THRESHOLD" ]]; then
        echo -e " ${RED}[WARNING - Threshold: ${MEM_THRESHOLD}%]${NC}"
        echo "  Details: Total: $(numfmt --to=iec-i --suffix=B $((mem_total * 1024)) 2>/dev/null || echo "${mem_total}KB"), Used: $(numfmt --to=iec-i --suffix=B $((mem_used * 1024)) 2>/dev/null || echo "${mem_used}KB")"
        return 1
    else
        echo -e " ${GREEN}[OK]${NC}"
        return 0
    fi
}

################################################################################
# Function: check_disk_usage
# Purpose: Check disk usage for all mounted filesystems and alert if threshold exceeded
################################################################################
check_disk_usage() {
    local status=0
    local disk_info
    local mount_point
    local disk_percent
    
    echo "Disk Usage:"
    
    # Parse df output, skip header
    while IFS= read -r line; do
        # Skip the header line
        if [[ "$line" =~ ^Filesystem ]]; then
            continue
        fi
        
        # Extract fields from df output
        mount_point=$(echo "$line" | awk '{print $NF}')
        disk_percent=$(echo "$line" | awk '{print $(NF-1)}' | sed 's/%//')
        
        echo -n "  ${mount_point}: ${disk_percent}%"
        
        if [[ "$disk_percent" -ge "$DISK_THRESHOLD" ]]; then
            echo -e " ${RED}[WARNING - Threshold: ${DISK_THRESHOLD}%]${NC}"
            status=1
        else
            echo -e " ${GREEN}[OK]${NC}"
        fi
    done < <(df -h | tail -n +2)
    
    return "$status"
}

################################################################################
# Function: generate_report
# Purpose: Generate health check report
################################################################################
generate_report() {
    local overall_status=0
    
    echo
    echo -e "${BLUE}========== System Health Check ==========${NC}"
    echo -e "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "Thresholds: CPU=${CPU_THRESHOLD}%, Memory=${MEM_THRESHOLD}%, Disk=${DISK_THRESHOLD}%"
    echo
    
    # Run all checks
    check_cpu_usage || overall_status=1
    check_memory_usage || overall_status=1
    check_disk_usage || overall_status=1
    
    echo
    echo -e "${BLUE}========== Summary ==========${NC}"
    
    if [[ "$overall_status" -eq 0 ]]; then
        echo -e "${GREEN}All systems healthy!${NC}"
    else
        echo -e "${RED}WARNING: One or more thresholds exceeded.${NC}"
    fi
    
    echo
    return "$overall_status"
}

################################################################################
# Main Execution
################################################################################
main() {
    # Parse command-line arguments
    parse_arguments "$@"
    
    # Validate thresholds
    validate_threshold "$CPU_THRESHOLD" "CPU threshold"
    validate_threshold "$MEM_THRESHOLD" "Memory threshold"
    validate_threshold "$DISK_THRESHOLD" "Disk threshold"
    
    # Generate health check report
    generate_report
}

# Execute main function
main "$@"
