#!/bin/bash

<< readme
This is a script for backup with 5-day rotation
Usage:
./backup.sh [source] [backup_folder]
If no arguments provided, will use settings from backup.conf
readme

# Config file support
CONFIG_FILE="backup.conf"

function create_sample_config(){
    echo "Creating sample config file: $CONFIG_FILE"
    cat > "$CONFIG_FILE" << EOF
# Backup Script Configuration
DEFAULT_SOURCE="/home/\$USER/Documents"
DEFAULT_BACKUP_DIR="/backup"
DEFAULT_RETENTION_DAYS=5
EOF
    echo "Config created! Edit $CONFIG_FILE and run script again"
    exit 0
}

function load_config(){
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Simple logging function
function log_message(){
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a backup.log
}

function display_usage(){
    echo "Usage: ./backup.sh [source] [backup_folder]"
    echo "  --setup     Create sample configuration file"
}

function validate_inputs(){
    # Handle setup command
    if [ "$1" = "--setup" ]; then
        create_sample_config
    fi
    
    # If no arguments, try config file
    if [ $# -eq 0 ]; then
        load_config
        if [ -z "$DEFAULT_SOURCE" ] || [ -z "$DEFAULT_BACKUP_DIR" ]; then
            log_message "ERROR: No config file found. Run: ./backup.sh --setup"
            display_usage
            exit 1
        fi
        source_dir="$DEFAULT_SOURCE"
        backup_dir="$DEFAULT_BACKUP_DIR"
        log_message "INFO: Using config file settings"
    elif [ $# -eq 2 ]; then
        source_dir="$1"
        backup_dir="$2"
    else
        log_message "ERROR: Please provide both source and backup directories"
        display_usage
        exit 1
    fi
    
    if [ ! -d "$source_dir" ]; then
        log_message "ERROR: Source directory '$source_dir' does not exist"
        exit 1
    fi
    
    if [ ! -r "$source_dir" ]; then
        log_message "ERROR: Cannot read source directory '$source_dir'"
        exit 1
    fi
    
    if [ ! -d "$backup_dir" ]; then
        log_message "INFO: Creating backup directory '$backup_dir'"
        mkdir -p "$backup_dir" || { log_message "ERROR: Cannot create backup directory"; exit 1; }
    fi
    
    if [ ! -w "$backup_dir" ]; then
        log_message "ERROR: Cannot write to backup directory '$backup_dir'"
        exit 1
    fi
    
    log_message "INFO: Input validation passed"
}

# Simple disk space check
function check_space(){
    local available=$(df "$backup_dir" | tail -1 | awk '{print $4}')
    if [ "$available" -lt 1000000 ]; then  # Less than 1GB
        log_message "WARNING: Low disk space (less than 1GB available)"
    else
        log_message "INFO: Disk space check passed"
    fi
}

log_message "INFO: Starting backup process"

validate_inputs "$@"

log_message "INFO: Source: $source_dir | Destination: $backup_dir"
check_space

# Load retention days from config
load_config
retention_days=${DEFAULT_RETENTION_DAYS:-5}

timestamp=$(date '+%Y-%m-%d-%H-%M-%S') 
backup_file="${backup_dir}/backup_${timestamp}.zip"

function create_backup(){
    log_message "INFO: Creating backup archive: $backup_file"
    zip -r "$backup_file" "$source_dir" > /dev/null
    
    if [ $? -eq 0 ]; then
        local file_size=$(ls -lh "$backup_file" | awk '{print $5}')
        log_message "SUCCESS: Backup completed successfully ($file_size)"
    else
        log_message "ERROR: Backup failed"
        rm -f "$backup_file"  # Clean up failed backup
        exit 1
    fi
}

function perform_rotation(){
   backups=($(ls -t "${backup_dir}/backup_"*.zip 2>/dev/null))
   if [ "${#backups[@]}" -gt "$retention_days" ]; then
           log_message "INFO: Performing rotation (keeping $retention_days backups)"
           backups_to_remove=("${backups[@]:$retention_days}")
           for backup in "${backups_to_remove[@]}";
           do 
                   log_message "INFO: Removing old backup: $(basename "$backup")"
                   rm -f ${backup}
           done
           log_message "INFO: Rotation completed"
   else
           log_message "INFO: No rotation needed (${#backups[@]} backups found)"
   fi
}

create_backup
perform_rotation

log_message "INFO: Backup process completed successfully"
