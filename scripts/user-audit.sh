#!/bin/bash

################################################################################
# user-audit.sh
#
# Purpose: Audit system users, groups, and sudo privileges. Useful for
#          security reviews and user management verification.
#
# Usage: ./user-audit.sh [OPTIONS]
#
# Examples:
#   ./user-audit.sh
#   ./user-audit.sh --show-shells
#   ./user-audit.sh --sudo-only
#
# Requirements:
#   - Bash 4.0+
#   - Common utilities: id, groups, getent, sudo
#
# Author: Titan DevOps Platform
# Last Modified: 2026-06-16
################################################################################

set -o errexit
set -o pipefail

# Options flags
SHOW_ALL=true
SHOW_SHELLS=false
SUDO_ONLY=false

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

Audit system users, groups, and security-related information.

OPTIONS:
    --show-shells       Include shell information for each user
    --sudo-only         Show only users with sudo access
    --groups-only       Show only group information
    --help              Display this help message

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --show-shells
    $(basename "$0") --sudo-only
    $(basename "$0") --groups-only

NOTES:
    - Requires read access to /etc/passwd, /etc/group, /etc/sudoers
    - Sudo information may require elevated privileges
    - Some commands may not show all info without root access

EOF
}

################################################################################
# Function: parse_arguments
# Purpose: Parse command-line arguments
################################################################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --show-shells)
                SHOW_SHELLS=true
                shift
                ;;
            --sudo-only)
                SUDO_ONLY=true
                SHOW_ALL=false
                shift
                ;;
            --groups-only)
                SHOW_GROUPS_ONLY=true
                SHOW_ALL=false
                shift
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
# Function: list_local_users
# Purpose: List all local users on the system
################################################################################
list_local_users() {
    echo -e "${BLUE}========== Local Users ==========${NC}"
    echo
    
    # Get users with UID >= 1000 (typical user threshold)
    echo "System Users (UID >= 1000):"
    echo -e "${GREEN}User ID      UID    GID    Shell${NC}"
    echo "-------------------------------------------"
    
    while IFS=: read -r username password uid gid gecos home shell; do
        # Skip users with UID < 1000 if showing all
        if [[ "$uid" -ge 1000 ]] || [[ "$SHOW_ALL" == true ]]; then
            if [[ "$SHOW_SHELLS" == true ]]; then
                printf "%-15s %-7s %-7s %s\n" "$username" "$uid" "$gid" "$shell"
            else
                printf "%-15s %-7s %-7s\n" "$username" "$uid" "$gid"
            fi
        fi
    done < /etc/passwd | sort -t: -k3 -n
    
    echo
}

################################################################################
# Function: list_system_users
# Purpose: List system users (UID < 1000)
################################################################################
list_system_users() {
    echo -e "${BLUE}========== System Users (UID < 1000) ==========${NC}"
    echo
    
    echo -e "${YELLOW}User ID      UID    GID    Shell${NC}"
    echo "-------------------------------------------"
    
    while IFS=: read -r username password uid gid gecos home shell; do
        if [[ "$uid" -lt 1000 ]] && [[ "$uid" -ne 0 ]]; then
            if [[ "$SHOW_SHELLS" == true ]]; then
                printf "%-15s %-7s %-7s %s\n" "$username" "$uid" "$gid" "$shell"
            else
                printf "%-15s %-7s %-7s\n" "$username" "$uid" "$gid"
            fi
        fi
    done < /etc/passwd | sort -t: -k3 -n
    
    echo
}

################################################################################
# Function: list_root_user
# Purpose: Display root user information
################################################################################
list_root_user() {
    echo -e "${BLUE}========== Root User ==========${NC}"
    
    while IFS=: read -r username password uid gid gecos home shell; do
        if [[ "$uid" -eq 0 ]]; then
            echo "User:        $username"
            echo "UID:         $uid"
            echo "GID:         $gid"
            echo "Home:        $home"
            if [[ "$SHOW_SHELLS" == true ]]; then
                echo "Shell:       $shell"
            fi
        fi
    done < /etc/passwd
    
    echo
}

################################################################################
# Function: list_groups
# Purpose: List all groups on the system
################################################################################
list_groups() {
    echo -e "${BLUE}========== System Groups ==========${NC}"
    echo
    
    echo -e "${GREEN}Group Name      GID${NC}"
    echo "-------------------------------------------"
    
    # Sort groups by GID
    sort -t: -k3 -n /etc/group | while IFS=: read -r group password gid members; do
        printf "%-15s %s\n" "$group" "$gid"
    done
    
    echo
}

################################################################################
# Function: list_sudo_users
# Purpose: List users with sudo privileges
################################################################################
list_sudo_users() {
    echo -e "${BLUE}========== Sudo Privileges ==========${NC}"
    echo
    
    # Try to read sudoers file (may require elevation)
    if [[ -r /etc/sudoers ]]; then
        echo "Users with explicit sudo entries:"
        grep -E "^[^#%].*\(ALL\)" /etc/sudoers 2>/dev/null | grep -v "^#" || echo "No explicit entries found"
        echo
        
        # Check for sudo group members
        echo "Users in sudo group (sudoers):"
        if getent group sudo &>/dev/null; then
            getent group sudo | cut -d: -f4 | tr ',' '\n' | grep -v '^$' | sort || echo "No members"
        else
            echo "sudo group not found"
        fi
    else
        # Alternative: check which users can run sudo
        echo -e "${YELLOW}Note: /etc/sudoers not readable (may require elevated privileges)${NC}"
        echo
        
        # Try sudo group as fallback
        if getent group sudo &>/dev/null; then
            echo "Users in sudo group:"
            getent group sudo | cut -d: -f4 | tr ',' '\n' | grep -v '^$' | sort || echo "No members"
        else
            echo "Could not determine sudo users. Try running with sudo."
        fi
    fi
    
    echo
}

################################################################################
# Function: list_user_groups
# Purpose: List groups for each user
################################################################################
list_user_groups() {
    echo -e "${BLUE}========== User Group Memberships ==========${NC}"
    echo
    
    while IFS=: read -r username password uid gid gecos home shell; do
        # Skip system users and root unless showing all
        if [[ "$uid" -ge 1000 ]] || [[ "$SHOW_ALL" == true ]]; then
            local user_groups
            user_groups=$(id -Gn "$username" 2>/dev/null | tr ' ' ',')
            echo -e "${GREEN}${username}${NC}:  ${user_groups}"
        fi
    done < /etc/passwd | sort
    
    echo
}

################################################################################
# Function: check_password_status
# Purpose: Check password status and aging information
################################################################################
check_password_status() {
    echo -e "${BLUE}========== Password Status ==========${NC}"
    echo
    
    if [[ ! -r /etc/shadow ]]; then
        echo -e "${YELLOW}Note: /etc/shadow not readable (requires elevated privileges)${NC}"
        echo
        return
    fi
    
    echo -e "${GREEN}User            Last Changed   Expires${NC}"
    echo "-------------------------------------------"
    
    while IFS=: read -r username password lastchange maxage minchange warning inactive expire; do
        # Skip system users
        userid=$(grep "^$username:" /etc/passwd | cut -d: -f3)
        if [[ "$userid" -ge 1000 ]]; then
            echo -e "${username} "
        fi
    done < /etc/shadow | head -5
    
    echo
}

################################################################################
# Function: generate_audit_report
# Purpose: Generate complete user and security audit report
################################################################################
generate_audit_report() {
    echo
    echo -e "${GREEN}Titan User & Security Audit Report${NC}"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname:  $(hostname)"
    echo
    
    # Show root
    list_root_user
    
    # Show system users
    list_system_users
    
    # Show local users
    list_local_users
    
    # Show groups
    list_groups
    
    # Show user group memberships
    list_user_groups
    
    # Show sudo privileges
    list_sudo_users
    
    # Try to show password status
    if [[ -r /etc/shadow ]]; then
        check_password_status
    fi
    
    echo -e "${GREEN}========== End of Report ==========${NC}"
    echo
}

################################################################################
# Function: generate_sudo_only_report
# Purpose: Generate report for sudo users only
################################################################################
generate_sudo_only_report() {
    echo
    echo -e "${GREEN}Titan Sudo Users Report${NC}"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    
    list_sudo_users
    
    echo -e "${GREEN}========== End of Report ==========${NC}"
    echo
}

################################################################################
# Main Execution
################################################################################
main() {
    parse_arguments "$@"
    
    if [[ "$SUDO_ONLY" == true ]]; then
        generate_sudo_only_report
    else
        generate_audit_report
    fi
}

# Execute main function
main "$@"
