#!/bin/bash

<< readme
This is a script for backup with 5-day rotation
Usage:
./backup.sh <path to your source> <path to backup folder>
readme

# Simple logging function
function log_message(){
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a backup.log
}

function display_usage(){
        echo "Usage: ./backup.sh <path to your source> <path to backup folder>"
}

function validate_inputs(){
    if [ $# -ne 2 ]; then 
        log_message "ERROR: Please provide both source and backup directories"
        display_usage
        exit 1
    fi
    
    if [ ! -d "$1" ]; then
        log_message "ERROR: Source directory '$1' does not exist"
        exit 1
    fi
    
    if [ ! -r "$1" ]; then
        log_message "ERROR: Cannot read source directory '$1'"
        exit 1
    fi
    
    if [ ! -d "$2" ]; then
        log_message "INFO: Creating backup directory '$2'"
        mkdir -p "$2" || { log_message "ERROR: Cannot create backup directory"; exit 1; }
    fi
    
    if [ ! -w "$2" ]; then
        log_message "ERROR: Cannot write to backup directory '$2'"
        exit 1
    fi
    
    log_message "INFO: Input validation passed"
}

# Simple disk space check
function check_space(){
    local available=$(df "$2" | tail -1 | awk '{print $4}')
    if [ "$available" -lt 1000000 ]; then  # Less than 1GB
        log_message "WARNING: Low disk space (less than 1GB available)"
    else
        log_message "INFO: Disk space check passed"
    fi
}


validate_inputs "$@"
check_space "$@"

source_dir=$1
timestamp=$(date '+%Y-%m-%d-%H-%M-%S') 
backup_dir=$2
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
   if [ "${#backups[@]}" -gt 5 ]; then
           log_message "INFO: Performing rotation (removing old backups)"
           backups_to_remove=("${backups[@]:5}")
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
