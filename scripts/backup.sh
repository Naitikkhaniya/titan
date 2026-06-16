#!/bin/bash

################################################################################
# backup.sh
#
# Purpose: Create timestamped backups of specified directories, compress
#          using tar, and store in a backup directory.
#
# Usage: ./backup.sh [SOURCE_DIR] [--backup-dir DIR] [--retention DAYS]
#
# Examples:
#   ./backup.sh /home/user/documents
#   ./backup.sh /etc --backup-dir /backup/configs --retention 30
#
# Requirements:
#   - Bash 4.0+
#   - tar, gzip
#
# Author: Titan DevOps Platform
# Last Modified: 2026-06-16
################################################################################

set -o errexit
set -o pipefail

# Default values
BACKUP_DIR="${HOME}/.local/titan/backups"
RETENTION_DAYS=30
COMPRESSION="gz" # gz for gzip, bz2 for bzip2, xz for xz

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
Usage: $(basename "$0") SOURCE_DIR [OPTIONS]

Create compressed backups of directories with automatic retention management.

ARGUMENTS:
    SOURCE_DIR              Directory to backup (required)

OPTIONS:
    --backup-dir DIR        Backup destination directory (default: ${BACKUP_DIR})
    --retention DAYS        Retention period in days (default: ${RETENTION_DAYS})
    --compression TYPE      Compression type: gz, bz2, xz (default: ${COMPRESSION})
    --help                  Display this help message

EXAMPLES:
    $(basename "$0") /home/user/documents
    $(basename "$0") /etc --backup-dir /backup/configs --retention 30
    $(basename "$0") /var/www --compression bz2 --retention 60

NOTES:
    - Source directory must exist and be readable
    - Backup filename format: {basename}-YYYY-MM-DD-HHMMSS.tar.{compression}
    - Old backups are automatically removed after retention period

EOF
}

################################################################################
# Function: parse_arguments
# Purpose: Parse command-line arguments
################################################################################
parse_arguments() {
    if [[ $# -lt 1 ]]; then
        echo "Error: SOURCE_DIR is required" >&2
        print_usage
        exit 1
    fi
    
    SOURCE_DIR="$1"
    shift
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --compression)
                COMPRESSION="$2"
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
# Function: validate_input
# Purpose: Validate source directory and parameters
################################################################################
validate_input() {
    # Check if source directory exists
    if [[ ! -d "$SOURCE_DIR" ]]; then
        echo -e "${RED}Error: Source directory does not exist: ${SOURCE_DIR}${NC}" >&2
        exit 1
    fi
    
    # Check if source directory is readable
    if [[ ! -r "$SOURCE_DIR" ]]; then
        echo -e "${RED}Error: Source directory is not readable: ${SOURCE_DIR}${NC}" >&2
        exit 1
    fi
    
    # Validate retention days
    if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Retention days must be a number${NC}" >&2
        exit 1
    fi
    
    # Validate compression type
    case "$COMPRESSION" in
        gz|bz2|xz)
            ;;
        *)
            echo -e "${RED}Error: Invalid compression type: ${COMPRESSION}${NC}" >&2
            echo "Valid options: gz, bz2, xz" >&2
            exit 1
            ;;
    esac
}

################################################################################
# Function: create_backup_directory
# Purpose: Create backup directory if it doesn't exist
################################################################################
create_backup_directory() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${BLUE}Creating backup directory: ${BACKUP_DIR}${NC}"
        mkdir -p "$BACKUP_DIR" || {
            echo -e "${RED}Error: Failed to create backup directory${NC}" >&2
            exit 1
        }
    fi
}

################################################################################
# Function: generate_backup_filename
# Purpose: Generate timestamped backup filename
# Output: Backup filename
################################################################################
generate_backup_filename() {
    local base_name
    base_name=$(basename "$SOURCE_DIR")
    local timestamp
    timestamp=$(date '+%Y-%m-%d-%H%M%S')
    
    echo "${base_name}-${timestamp}.tar.${COMPRESSION}"
}

################################################################################
# Function: create_backup
# Purpose: Create compressed backup of source directory
################################################################################
create_backup() {
    local backup_filename
    backup_filename=$(generate_backup_filename)
    local backup_filepath="${BACKUP_DIR}/${backup_filename}"
    
    echo -e "${BLUE}========== Backup Starting ==========${NC}"
    echo "Source:           ${SOURCE_DIR}"
    echo "Destination:      ${backup_filepath}"
    echo "Compression:      ${COMPRESSION}"
    echo "Timestamp:        $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    
    # Create backup based on compression type
    case "$COMPRESSION" in
        gz)
            tar -czf "$backup_filepath" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" || {
                echo -e "${RED}Error: Failed to create backup${NC}" >&2
                return 1
            }
            ;;
        bz2)
            tar -cjf "$backup_filepath" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" || {
                echo -e "${RED}Error: Failed to create backup${NC}" >&2
                return 1
            }
            ;;
        xz)
            tar -cJf "$backup_filepath" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" || {
                echo -e "${RED}Error: Failed to create backup${NC}" >&2
                return 1
            }
            ;;
    esac
    
    # Get backup file size
    local backup_size
    backup_size=$(du -h "$backup_filepath" | cut -f1)
    
    echo -e "${GREEN}✓ Backup created successfully${NC}"
    echo "Filename:         ${backup_filename}"
    echo "Size:             ${backup_size}"
    echo "Timestamp:        $(date '+%Y-%m-%d %H:%M:%S')"
    echo
}

################################################################################
# Function: cleanup_old_backups
# Purpose: Remove backups older than retention period
################################################################################
cleanup_old_backups() {
    local base_name
    base_name=$(basename "$SOURCE_DIR")
    
    echo -e "${BLUE}========== Cleanup Starting ==========${NC}"
    echo "Retention Period: ${RETENTION_DAYS} days"
    echo
    
    local removed_count=0
    local freed_space=0
    
    # Find and remove old backups
    while IFS= read -r old_backup; do
        if [[ -n "$old_backup" ]]; then
            local file_size
            file_size=$(du -b "$old_backup" | cut -f1)
            freed_space=$((freed_space + file_size))
            removed_count=$((removed_count + 1))
            
            echo "Removing: $(basename "$old_backup")"
            rm -f "$old_backup" || {
                echo -e "${YELLOW}Warning: Failed to remove ${old_backup}${NC}" >&2
            }
        fi
    done < <(find "$BACKUP_DIR" -name "${base_name}-*.tar.${COMPRESSION}" -mtime "+${RETENTION_DAYS}" 2>/dev/null)
    
    if [[ "$removed_count" -gt 0 ]]; then
        local freed_size
        freed_size=$(numfmt --to=iec-i --suffix=B "$freed_space" 2>/dev/null || echo "${freed_space} bytes")
        echo -e "${GREEN}✓ Removed ${removed_count} old backup(s)${NC}"
        echo "Space freed: ${freed_size}"
    else
        echo -e "${GREEN}✓ No old backups to remove${NC}"
    fi
    echo
}

################################################################################
# Function: list_backups
# Purpose: List all backups for the source directory
################################################################################
list_backups() {
    local base_name
    base_name=$(basename "$SOURCE_DIR")
    
    echo -e "${BLUE}========== Available Backups ==========${NC}"
    
    if ls -1 "$BACKUP_DIR"/${base_name}-*.tar.${COMPRESSION} 2>/dev/null | wc -l | grep -q "^0$"; then
        echo "No backups found for: ${base_name}"
    else
        ls -lh "$BACKUP_DIR"/${base_name}-*.tar.${COMPRESSION} 2>/dev/null | awk '{print $9, "(" $5 ")"}'
    fi
    echo
}

################################################################################
# Main Execution
################################################################################
main() {
    parse_arguments "$@"
    validate_input
    create_backup_directory
    create_backup
    cleanup_old_backups
    list_backups
    
    echo -e "${GREEN}========== Backup Complete ==========${NC}"
}

# Execute main function
main "$@"
