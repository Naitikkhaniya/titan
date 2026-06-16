#!/bin/bash

################################################################################
# log-analyzer.sh
#
# Purpose: Analyze system logs to identify patterns, common errors, and
#          warning frequencies. Useful for troubleshooting and monitoring.
#
# Usage: ./log-analyzer.sh [LOG_FILE] [OPTIONS]
#
# Examples:
#   ./log-analyzer.sh /var/log/syslog
#   ./log-analyzer.sh /var/log/auth.log --top-errors 10
#   ./log-analyzer.sh --journal --hours 24
#
# Requirements:
#   - Bash 4.0+
#   - grep, sort, uniq, wc
#   - journalctl (for systemd journal)
#
# Author: Titan DevOps Platform
# Last Modified: 2026-06-16
################################################################################

set -o errexit
set -o pipefail

# Default values
TOP_ENTRIES=5
USE_JOURNAL=false
HOURS_BACK=24
LOG_FILE=""

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
Usage: $(basename "$0") [LOG_FILE] [OPTIONS]

Analyze system logs for patterns, errors, and warnings.

ARGUMENTS:
    LOG_FILE                Log file to analyze (optional if using --journal)

OPTIONS:
    --journal               Analyze systemd journal instead of file
    --hours N               Look back N hours in journal (default: ${HOURS_BACK})
    --top-errors N          Show top N error patterns (default: ${TOP_ENTRIES})
    --help                  Display this help message

EXAMPLES:
    $(basename "$0") /var/log/syslog
    $(basename "$0") /var/log/auth.log --top-errors 10
    $(basename "$0") --journal --hours 48
    $(basename "$0") --journal --top-errors 20

NOTES:
    - Requires read access to log files
    - Journal access may require elevated privileges
    - Patterns are extracted from log lines

EOF
}

################################################################################
# Function: parse_arguments
# Purpose: Parse command-line arguments
################################################################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --journal)
                USE_JOURNAL=true
                shift
                ;;
            --hours)
                HOURS_BACK="$2"
                shift 2
                ;;
            --top-errors)
                TOP_ENTRIES="$2"
                shift 2
                ;;
            --help)
                print_usage
                exit 0
                ;;
            -*)
                echo "Error: Unknown option: $1" >&2
                print_usage
                exit 1
                ;;
            *)
                LOG_FILE="$1"
                shift
                ;;
        esac
    done
}

################################################################################
# Function: validate_input
# Purpose: Validate input parameters and file access
################################################################################
validate_input() {
    if [[ "$USE_JOURNAL" == false ]]; then
        if [[ -z "$LOG_FILE" ]]; then
            echo -e "${RED}Error: LOG_FILE is required when not using --journal${NC}" >&2
            print_usage
            exit 1
        fi
        
        if [[ ! -f "$LOG_FILE" ]]; then
            echo -e "${RED}Error: Log file not found: ${LOG_FILE}${NC}" >&2
            exit 1
        fi
        
        if [[ ! -r "$LOG_FILE" ]]; then
            echo -e "${RED}Error: Log file is not readable: ${LOG_FILE}${NC}" >&2
            exit 1
        fi
    else
        # Check if journalctl is available
        if ! command -v journalctl &> /dev/null; then
            echo -e "${RED}Error: journalctl not found. systemd journal not available.${NC}" >&2
            exit 1
        fi
    fi
    
    # Validate top entries
    if ! [[ "$TOP_ENTRIES" =~ ^[0-9]+$ ]] || [[ "$TOP_ENTRIES" -lt 1 ]]; then
        echo -e "${RED}Error: top-errors must be a positive number${NC}" >&2
        exit 1
    fi
    
    # Validate hours back
    if ! [[ "$HOURS_BACK" =~ ^[0-9]+$ ]] || [[ "$HOURS_BACK" -lt 1 ]]; then
        echo -e "${RED}Error: hours must be a positive number${NC}" >&2
        exit 1
    fi
}

################################################################################
# Function: get_log_content
# Purpose: Get log content from file or journal
# Output: Log content
################################################################################
get_log_content() {
    if [[ "$USE_JOURNAL" == true ]]; then
        # Use journalctl to get recent logs
        journalctl --since "${HOURS_BACK} hours ago" 2>/dev/null || journalctl --since "1 hour ago"
    else
        cat "$LOG_FILE"
    fi
}

################################################################################
# Function: count_log_levels
# Purpose: Count ERROR, WARNING, INFO messages
################################################################################
count_log_levels() {
    echo -e "${BLUE}========== Log Level Summary ==========${NC}"
    
    local log_content
    log_content=$(get_log_content)
    
    local error_count
    local warning_count
    local info_count
    
    error_count=$(echo "$log_content" | grep -i "error\|err\|fail\|fatal" | wc -l)
    warning_count=$(echo "$log_content" | grep -i "warn\|warning" | wc -l)
    info_count=$(echo "$log_content" | grep -i "info\|information" | wc -l)
    
    echo -e "Errors:     ${RED}${error_count}${NC}"
    echo -e "Warnings:   ${YELLOW}${warning_count}${NC}"
    echo -e "Info:       ${GREEN}${info_count}${NC}"
    echo -e "Total Lines: $(echo "$log_content" | wc -l)"
    echo
}

################################################################################
# Function: show_common_errors
# Purpose: Extract and display most common error patterns
################################################################################
show_common_errors() {
    echo -e "${BLUE}========== Top ${TOP_ENTRIES} Most Common Errors ==========${NC}"
    
    local log_content
    log_content=$(get_log_content)
    
    # Extract error lines, normalize patterns, and count
    local error_lines
    error_lines=$(echo "$log_content" | grep -i "error\|err\|fail\|fatal" | head -100)
    
    if [[ -z "$error_lines" ]]; then
        echo "No errors found in logs."
        echo
        return
    fi
    
    # Extract key error messages/patterns
    echo "$error_lines" | \
        sed 's/.*\(error\|err\|fail\|fatal\).*/\1/' | \
        sort | uniq -c | sort -rn | head -n "$TOP_ENTRIES" | \
        while read count pattern; do
            echo -e "${RED}[$count occurrences]${NC} $pattern"
        done
    
    echo
}

################################################################################
# Function: show_common_warnings
# Purpose: Extract and display most common warning patterns
################################################################################
show_common_warnings() {
    echo -e "${BLUE}========== Top ${TOP_ENTRIES} Most Common Warnings ==========${NC}"
    
    local log_content
    log_content=$(get_log_content)
    
    # Extract warning lines
    local warning_lines
    warning_lines=$(echo "$log_content" | grep -i "warn\|warning" | head -100)
    
    if [[ -z "$warning_lines" ]]; then
        echo "No warnings found in logs."
        echo
        return
    fi
    
    # Extract key warning messages/patterns
    echo "$warning_lines" | \
        sed 's/.*\(warn\|warning\).*/\1/' | \
        sort | uniq -c | sort -rn | head -n "$TOP_ENTRIES" | \
        while read count pattern; do
            echo -e "${YELLOW}[$count occurrences]${NC} $pattern"
        done
    
    echo
}

################################################################################
# Function: analyze_recent_errors
# Purpose: Show recent error entries
################################################################################
analyze_recent_errors() {
    echo -e "${BLUE}========== Recent Error Entries ==========${NC}"
    
    local log_content
    log_content=$(get_log_content)
    
    local recent_errors
    recent_errors=$(echo "$log_content" | grep -i "error\|err\|fail\|fatal" | tail -5)
    
    if [[ -z "$recent_errors" ]]; then
        echo "No recent errors found."
        echo
        return
    fi
    
    echo "$recent_errors" | while read -r line; do
        echo -e "${RED}${line:0:120}${NC}"
        if [[ ${#line} -gt 120 ]]; then
            echo "..."
        fi
    done
    echo
}

################################################################################
# Function: generate_report
# Purpose: Generate complete log analysis report
################################################################################
generate_report() {
    echo
    echo -e "${GREEN}Titan Log Analysis Report${NC}"
    
    if [[ "$USE_JOURNAL" == true ]]; then
        echo "Source:   systemd journal (last ${HOURS_BACK} hours)"
    else
        echo "Source:   ${LOG_FILE}"
    fi
    echo "Time:     $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    
    count_log_levels
    show_common_errors
    show_common_warnings
    analyze_recent_errors
    
    echo -e "${GREEN}========== End of Report ==========${NC}"
    echo
}

################################################################################
# Main Execution
################################################################################
main() {
    parse_arguments "$@"
    validate_input
    generate_report
}

# Execute main function
main "$@"
