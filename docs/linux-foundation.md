# Titan Linux Foundation Module

This module provides essential Linux system administration and monitoring scripts for the Titan local DevOps platform on WSL Ubuntu 26.04.

## Overview

The Linux Foundation module includes five core scripts designed to help developers and DevOps engineers understand, monitor, and manage local Linux systems. These scripts follow Bash best practices and include comprehensive documentation for learning and reference.

## Scripts Directory Structure

```
scripts/
├── system-info.sh       # Display comprehensive system information
├── health-check.sh      # Monitor system health and resource usage
├── backup.sh            # Create timestamped backups with retention
├── log-analyzer.sh      # Analyze system logs for patterns and errors
└── user-audit.sh        # Audit users, groups, and sudo privileges
```

## Quick Start

Make scripts executable:

```bash
chmod +x scripts/*.sh
```

Run a script:

```bash
./scripts/system-info.sh
./scripts/health-check.sh
./scripts/backup.sh /home/user/documents
./scripts/log-analyzer.sh /var/log/syslog
./scripts/user-audit.sh
```

---

## Script Documentation

### 1. system-info.sh

**Purpose**: Display comprehensive system information for understanding your local environment.

**Key Information Displayed**:
- Operating system version, kernel, and architecture
- CPU information (cores, model, frequency)
- Memory (total, used, available, percentage)
- Disk usage for all mounted filesystems
- System uptime
- Current user and group information

**Usage**:

```bash
./scripts/system-info.sh
```

**Output Example**:
```
======================================
Operating System Information
======================================
Kernel Name:     Linux
Kernel Release:  5.15.0-86-generic
Kernel Version:  #96-Ubuntu SMP ...
Hardware Arch:   x86_64
Distribution:    Ubuntu 26.04 LTS
...
```

**Best Practices**:
- Run regularly to establish baseline system performance
- Redirect output to a file for archival: `./system-info.sh > sysinfo_$(date +%Y%m%d_%H%M%S).txt`
- Use in monitoring scripts to detect configuration changes

**Learning Objectives**:
- Understanding `/proc/meminfo` and `/proc/cpuinfo`
- Using common utilities: `uname`, `lsb_release`, `free`, `df`
- Parsing system files programmatically
- Formatting output for human readability

---

### 2. health-check.sh

**Purpose**: Monitor CPU, memory, and disk usage against configurable thresholds to identify resource bottlenecks.

**Key Features**:
- Real-time CPU usage monitoring
- Memory usage analysis with detailed breakdown
- Disk usage checks for all mounted filesystems
- Configurable warning thresholds (default: 80%)
- Color-coded output for easy interpretation

**Usage**:

```bash
# Basic usage with defaults (80% thresholds)
./scripts/health-check.sh

# Custom thresholds
./scripts/health-check.sh --cpu-threshold 75 --mem-threshold 85

# Specific disk threshold
./scripts/health-check.sh --disk-threshold 90
```

**Output Example**:
```
========== System Health Check ==========
CPU Usage:     42% [OK]
Memory Usage:  65% [OK]
Disk Usage:
  /: 45% [OK]
  /home: 72% [OK]
```

**Configuration Options**:
- `--cpu-threshold N`: CPU usage threshold (0-100%)
- `--mem-threshold N`: Memory usage threshold (0-100%)
- `--disk-threshold N`: Disk usage threshold (0-100%)

**Best Practices**:
- Schedule regular health checks: `0 * * * * /path/to/health-check.sh >> health.log`
- Adjust thresholds based on workload expectations
- Investigate warnings promptly to prevent system issues
- Track health-check output over time to identify trends

**Learning Objectives**:
- Understanding CPU usage metrics from `top` and `/proc/stat`
- Memory management and available vs. free memory
- Filesystem usage patterns with `df`
- Threshold-based alerting mechanisms
- Error handling and validation in Bash

---

### 3. backup.sh

**Purpose**: Create automated, timestamped backups with compression and retention management.

**Key Features**:
- Automatic timestamped backup filenames: `{directory}-YYYY-MM-DD-HHMMSS.tar.{compression}`
- Multiple compression algorithms: gzip (gz), bzip2 (bz2), xz
- Automatic cleanup of backups older than retention period
- Detailed backup reporting with file sizes
- Directory structure preservation

**Usage**:

```bash
# Basic backup with defaults (30-day retention, gzip compression)
./scripts/backup.sh /home/user/documents

# Custom backup directory
./scripts/backup.sh /etc --backup-dir /backup/configs

# Extended retention and compression
./scripts/backup.sh /var/www --retention 90 --compression xz

# Bzip2 compression
./scripts/backup.sh /home/user/data --compression bz2
```

**Output Example**:
```
========== Backup Starting ==========
Source:           /home/user/documents
Destination:      /home/user/.local/titan/backups/documents-2026-06-16-143022.tar.gz
Compression:      gz
✓ Backup created successfully
Filename:         documents-2026-06-16-143022.tar.gz
Size:             2.3G
```

**Configuration Options**:
- `--backup-dir DIR`: Backup destination directory
- `--retention DAYS`: Keep backups for N days (default: 30)
- `--compression TYPE`: Compression algorithm (gz/bz2/xz)

**Default Backup Location**:
```
${HOME}/.local/titan/backups/
```

**Best Practices**:
- Test restore process regularly
- Store critical backups on external storage
- Schedule daily backups: `0 2 * * * /path/to/backup.sh /important/dir`
- Monitor backup directory size: `du -sh ${HOME}/.local/titan/backups/`
- Use different retention periods for different data types
- Verify backup integrity after creation

**Compression Trade-offs**:
| Algorithm | Speed | Ratio | Comments |
|-----------|-------|-------|----------|
| gzip (gz) | Fast  | Good  | Default, balanced |
| bzip2     | Slow  | Better| Higher compression |
| xz        | Slow  | Best  | Maximum compression |

**Learning Objectives**:
- Understanding tar archive creation and restoration
- Compression algorithms and trade-offs
- Finding and deleting old files with `find`
- Calculating file sizes with `du` and `stat`
- Timestamp formatting and date arithmetic
- Error handling for file operations

---

### 4. log-analyzer.sh

**Purpose**: Analyze system logs to identify patterns, common errors, and warning frequencies for troubleshooting and monitoring.

**Key Features**:
- Count errors, warnings, and info messages
- Identify most common error patterns
- Show recent error entries
- Support for both files and systemd journal
- Configurable analysis depth and time window

**Usage**:

```bash
# Analyze a specific log file
./scripts/log-analyzer.sh /var/log/syslog

# Analyze auth log with top 10 errors
./scripts/log-analyzer.sh /var/log/auth.log --top-errors 10

# Analyze systemd journal (last 24 hours)
./scripts/log-analyzer.sh --journal

# Analyze journal for last 48 hours
./scripts/log-analyzer.sh --journal --hours 48

# Analyze with extended error details
./scripts/log-analyzer.sh /var/log/syslog --top-errors 20
```

**Output Example**:
```
========== Log Level Summary ==========
Errors:     15
Warnings:   42
Info:       128
Total Lines: 1847

========== Top 5 Most Common Errors ==========
[8 occurrences] Connection refused
[5 occurrences] Timeout
[3 occurrences] Permission denied
```

**Configuration Options**:
- `--journal`: Analyze systemd journal instead of file
- `--hours N`: Look back N hours in journal (default: 24)
- `--top-errors N`: Show top N error patterns (default: 5)

**Common Log Locations**:
- `/var/log/syslog`: System log (Debian/Ubuntu)
- `/var/log/auth.log`: Authentication log
- `/var/log/kernel.log`: Kernel messages
- `/var/log/apt/history.log`: APT package manager
- systemd journal: `journalctl`

**Best Practices**:
- Schedule periodic analysis: `0 3 * * * /path/to/log-analyzer.sh /var/log/syslog >> analysis.log`
- Rotate logs to prevent unbounded growth
- Correlate errors across multiple log files
- Investigate error spikes immediately
- Keep analysis results for historical comparison

**Learning Objectives**:
- Log file format understanding and parsing
- Pattern matching with `grep` and `sed`
- Counting and sorting with `sort` and `uniq`
- Working with systemd journal via `journalctl`
- Filtering and normalizing unstructured text
- Building simple analytics pipelines

---

### 5. user-audit.sh

**Purpose**: Audit system users, groups, and sudo privileges for security verification and user management.

**Key Features**:
- List all system and local users with UIDs and GIDs
- Display group memberships and permissions
- Identify users with sudo privileges
- Show shell information for users
- Separate views for system vs. local users
- Password status information (if accessible)

**Usage**:

```bash
# Full user and group audit
./scripts/user-audit.sh

# Show user shell information
./scripts/user-audit.sh --show-shells

# Show only sudo users
./scripts/user-audit.sh --sudo-only

# Show only group information
./scripts/user-audit.sh --groups-only
```

**Output Example**:
```
========== Root User ==========
User:        root
UID:         0
GID:         0
Home:        /root

========== Local Users (UID >= 1000) ==========
User ID          UID     GID     Shell
---------------------------------------
ubuntu           1000    1000    /bin/bash
developer        1001    1001    /bin/bash

========== Sudo Privileges ==========
Users in sudo group (sudoers):
ubuntu
developer
```

**Configuration Options**:
- `--show-shells`: Include shell information for each user
- `--sudo-only`: Show only users with sudo access
- `--groups-only`: Show only group information

**User ID Ranges** (Standard Linux):
| Range | Type | Examples |
|-------|------|----------|
| 0 | Root | root |
| 1-999 | System | daemon, bin, sys, www-data |
| 1000+ | Local/Regular | ubuntu, developer, users |

**Key Files**:
- `/etc/passwd`: User account information
- `/etc/shadow`: User password information (requires elevation)
- `/etc/group`: Group definitions
- `/etc/sudoers`: Sudo configuration

**Best Practices**:
- Audit users regularly for security compliance
- Remove unused user accounts promptly
- Review sudo privileges monthly
- Restrict sudo access to necessary users only
- Use strong authentication mechanisms
- Monitor user login attempts in `/var/log/auth.log`

**Learning Objectives**:
- Understanding `/etc/passwd` and `/etc/group` structure
- UID/GID ranges and their significance
- User authentication and sudo mechanisms
- Group-based access control
- Reading restricted files with appropriate permissions
- Security audit methodologies

---

## Common Workflows

### Daily System Monitoring

```bash
#!/bin/bash
# Daily monitoring routine

# Check system info
./scripts/system-info.sh > daily_info_$(date +%Y%m%d).txt

# Health check
./scripts/health-check.sh --cpu-threshold 75 >> daily_health.log

# Analyze recent logs
./scripts/log-analyzer.sh /var/log/syslog --top-errors 5 >> daily_analysis.log
```

### Weekly Backup and Audit

```bash
#!/bin/bash
# Weekly backup and security audit

# Backup important directories
./scripts/backup.sh /home/user/work --retention 60
./scripts/backup.sh /etc --retention 90 --compression xz

# Run security audit
./scripts/user-audit.sh > weekly_audit_$(date +%Y%m%d).txt
```

### Troubleshooting Resource Issues

```bash
#!/bin/bash
# When system appears slow

# Get detailed system info
./scripts/system-info.sh

# Check current health
./scripts/health-check.sh --cpu-threshold 50 --mem-threshold 70

# Analyze logs for patterns
./scripts/log-analyzer.sh /var/log/syslog --top-errors 20
./scripts/log-analyzer.sh --journal --hours 2
```

---

## Bash Best Practices Used in These Scripts

### 1. Error Handling

```bash
# Exit on error
set -o errexit

# Exit on pipe failure
set -o pipefail

# Exit on undefined variable
set -o nounset
```

### 2. Function Documentation

Each function includes:
- Purpose statement
- Arguments documentation
- Return value explanation
- Usage examples

### 3. Input Validation

- Check required arguments
- Validate file existence and readability
- Verify numeric inputs
- Test for available utilities

### 4. Clear Output

- Use colors for different severity levels
- Provide structured, easy-to-read reports
- Include timestamps
- Show command execution steps

### 5. Modularity

- Separate concerns into functions
- Make scripts composable
- Allow for easy extension
- Keep configurations in variables

---

## Integration with Titan

These scripts form the foundation for:
- **Phase 2**: Environment monitoring and health checks
- **Phase 3**: Tool integration and automation
- **Phase 4**: Sample deployment validation
- **Phase 5**: Observability infrastructure

Future scripts and tools will build on these foundations to create a complete local DevOps platform.

---

## Troubleshooting

### Permission Denied

```bash
# Make scripts executable
chmod +x scripts/*.sh
```

### Command Not Found

Ensure required utilities are installed:

```bash
# Check availability
which tar gzip bzip2 xz
which journalctl
which id groups
```

### Cannot Read Log Files

Log files typically require elevated privileges:

```bash
# Use sudo for sensitive logs
sudo ./scripts/log-analyzer.sh /var/log/auth.log
sudo ./scripts/user-audit.sh
```

### Backup Directory Permission Issues

```bash
# Ensure backup directory is accessible
mkdir -p ~/.local/titan/backups
chmod 700 ~/.local/titan/backups
```

---

## Learning Resources

- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Linux man pages online](https://man7.org/linux/)
- [Advanced Bash Scripting Guide](https://www.tldp.org/LDP/abs/html/)
- [Ubuntu Server Documentation](https://ubuntu.com/server/docs)

---

## Next Steps

After mastering these Linux Foundation scripts:

1. Extend scripts with additional metrics and reporting
2. Integrate with monitoring and alerting systems
3. Build automated response procedures for alerts
4. Create orchestration workflows combining multiple scripts
5. Develop web-based dashboards for visualization

