#!/bin/bash
# highlycurated.sh (Automatic file organization for ~/Downloads)
# Author: github.com/narlyseorg
# Trigger: Automator Folder Action (Finder)
# Compatibility: macOS (Bash 3.2+)
# - Safe for repeated triggers (idempotent)
# - Production logging with rotation

## -- Configuration -- ##
DOWNLOADS_DIR="$HOME/Downloads"
LOG_FILE="$HOME/Library/Logs/highlycurated.log"
LOCK_FILE="/tmp/highlycurated.lock"
MAX_LOG_SIZE=1048576

## -- Ensure log dir exists -- ##
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

## -- Logging + rotation -- ##
log() {
    if [[ -f "$LOG_FILE" ]]; then
        local size
        size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
        if [[ "$size" -gt $MAX_LOG_SIZE ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.old" 2>/dev/null || true
        fi
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    log "ERROR: $*"
}

## -- Atomic lock using noclobber to prevent race conditions -- ##
acquire_lock() {
    if ( umask 077; set -o noclobber; echo "$$" > "$LOCK_FILE" ) 2>/dev/null; then
        log "Lock acquired (pid $$) with restricted permissions"
        return 0
    fi

    local old_pid
    old_pid=$(cat "$LOCK_FILE" 2>/dev/null)

    if [[ -n "$old_pid" ]] && ! kill -0 "$old_pid" 2>/dev/null; then
        log "Stale lock detected (pid $old_pid is dead). Cleaning up..."
        rm -f "$LOCK_FILE"
        
        if ( umask 077; set -o noclobber; echo "$$" > "$LOCK_FILE" ) 2>/dev/null; then
            log "Lock acquired after cleanup (pid $$)"
            return 0
        fi
    fi

    log "Another instance is running (pid ${old_pid:-unknown}), exiting"
    exit 0
}

release_lock() {
    if [[ $(cat "$LOCK_FILE" 2>/dev/null) == "$$" ]]; then
        rm -f "$LOCK_FILE"
        log "Lock released"
    fi
}

trap 'release_lock' EXIT INT TERM

## -- Skip patterns -- ##
is_skip_extension() {
    local ext_lower
    ext_lower=$(to_lower "$1")
    case "$ext_lower" in
        crdownload|download|part|tmp|opdownload) return 0 ;;
        ds_store|localized) return 0 ;;
        *) return 1 ;;
    esac
}

## -- Category by filename (extensionless / special files) -- ##
get_category_by_filename() {
    local name_lower
    name_lower=$(to_lower "$1")
    case "$name_lower" in
        dockerfile|makefile|vagrantfile|jenkinsfile|procfile|gemfile|rakefile|brewfile|podfile|fastfile|cartfile|dangerfile|guardfile|thorfile|capfile|berksfile|cheffile|puppetfile|modulefile|buildfile|gradlew|cmakelists.txt|license|readme|changelog|authors|contributors|copying|install|maintainers|news|thanks|todo|version)
            echo "Scripts"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

## -- Category by extension -- ##
get_category() {
    local ext_lower
    ext_lower=$(to_lower "$1")
    case "$ext_lower" in
        doc|docx|odt|pdf|xls|xlsx|ods|csv|ppt|pptx|odp|pages|numbers|txt|rtf|md|tex|log|epub|mobi|wps|msg|wpd)
            echo "Documents" ;;
        py|ipynb|js|jsx|ts|tsx|html|css|scss|java|class|jar|c|cpp|h|cs|php|swift|go|rb|pl|rs|sh|bash|zsh|bat|ps1|lua|r|sql|sqlite|db|json|xml|yaml|yml|toml|ini|cfg|config|env|htaccess|gitignore|pkl|kt|dart)
            echo "Scripts" ;;
        jpg|jpeg|png|gif|webp|tiff|tif|bmp|heic|svg|ico|psd|ai|eps|indd|raw|cr2|nef|orf|arw|dng|xcf)
            echo "Images" ;;
        zip|rar|7z|tar|gz|tgz|bz2|tbz|xz|zst)
            echo "Compressed" ;;
        app|pkg|exe|msi|apk|xapk|ipa|apkm|deb|rpm|appx|bin|dmg)
            echo "Programs" ;;
        pem|crt|cer|der|p12|pfx|pki|pub|key|gpg|ovpn|asc)
            echo "Certificates" ;;
        mp4|mkv|mov|avi|wmv|flv|webm|m4v|mpg|mpeg|3gp|ts|vob|srt|ass)
            echo "Videos" ;;
        mp3|wav|aac|flac|ogg|m4a|wma|alac|mid|midi)
            echo "Music" ;;
        iso|ova|vdi|vbox|vmdk|qcow2|img)
            echo "Disks" ;;
        ttf|otf|woff|woff2)
            echo "Fonts" ;;
        torrent)
            echo "Torrents" ;;
        *)
            echo "Others" ;;
    esac
}

## -- Generate unique filename -- ##
get_unique_path() {
    local dest_dir="$1"
    local filename="$2"
    local name="${filename%.*}"
    local ext="${filename##*.}"
    local target="$dest_dir/$filename"
    local counter=2

    [[ "$name" == "$ext" ]] && ext=""

    while [[ -e "$target" ]]; do
        if [[ -n "$ext" && "$ext" != "$name" ]]; then
            target="$dest_dir/${name} (${counter}).${ext}"
        else
            target="$dest_dir/${filename} (${counter})"
        fi
        counter=$((counter + 1))
    done

    echo "$target"
}

## -- Process a single file -- ##
process_file() {
    local filepath="$1"
    local filename ext category dest_dir dest_path

    [[ ! -f "$filepath" ]] && return 0

    filename=$(basename "$filepath")
    [[ "$filename" == .* ]] && return 0

    [[ "$filename" == *.* ]] && ext="${filename##*.}" || ext=""

    [[ -n "$ext" ]] && is_skip_extension "$ext" && return 0

    if ! category=$(get_category_by_filename "$filename"); then
        category=$(get_category "$ext")
    fi

    dest_dir="$DOWNLOADS_DIR/$category"
    mkdir -p "$dest_dir" 2>/dev/null || {
        log_error "Failed to create directory: $dest_dir"
        return 1
    }

    dest_path=$(get_unique_path "$dest_dir" "$filename")

    [[ ! -f "$filepath" ]] && return 0

    if mv "$filepath" "$dest_path" 2>/dev/null; then
        log "Moved: $filename -> $category/$(basename "$dest_path")"
    else
        log_error "Failed to move: $filename"
        return 1
    fi
}

## -- Main -- ##
acquire_lock

while IFS= read -r -d '' filepath; do
    process_file "$filepath"
done < <(find "$DOWNLOADS_DIR" -maxdepth 1 -type f -print0 2>/dev/null)

log "Sort completed"
