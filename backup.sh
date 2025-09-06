#!/bin/bash

<< readme
This is a script for backup with 5-day rotation
Usage:
./backup.sh <path to your source> <path to backup folder>
readme

function display_usage(){
        echo "Usage: ./backup.sh <path to your source> <path to backup folder>"
}

function validate_inputs(){
    if [ $# -ne 2 ]; then 
        echo "ERROR: Please provide both source and backup directories"
        display_usage
        exit 1
    fi
   
    if [ ! -d "$1" ]; then
        echo "ERROR: Source directory '$1' does not exist"
        exit 1
    fi
    
    if [ ! -r "$1" ]; then
        echo "ERROR: Cannot read source directory '$1'"
        exit 1
    fi
    
    if [ ! -d "$2" ]; then
        echo "Creating backup directory '$2'..."
        mkdir -p "$2" || { echo "ERROR: Cannot create backup directory"; exit 1; }
    fi
    
    if [ ! -w "$2" ]; then
        echo "ERROR: Cannot write to backup directory '$2'"
        exit 1
    fi
}


validate_inputs "$@"

source_dir=$1
timestamp=$(date '+%Y-%m-%d-%H-%M-%S') 
backup_dir=$2

function create_backup(){
    zip -r "${backup_dir}/backup_${timestamp}.zip" "${source_dir}" > /dev/null
    if [ $? -eq 0 ]; then
            echo "backup generated successfully for ${timestamp}"
    else
            echo "ERROR: Backup failed"
            exit 1
    fi
}

function perform_rotation(){
   backups=($(ls -t "${backup_dir}/backup_"*.zip 2>/dev/null))
   if [ "${#backups[@]}" -gt 5 ]; then
           echo "Performing rotation for 5 days"
           backups_to_remove=("${backups[@]:5}")
           echo "${backups_to_remove[@]}" 
           for backup in "${backups_to_remove[@]}";
           do 
                   rm -f ${backup}
           done
   fi
}

create_backup
perform_rotation
