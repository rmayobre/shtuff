#!/bin/bash

source ./shtuff.sh

# Progress Bar Functions for File Operations
# Usage: Source this script and call the functions as needed


# Function to draw a progress bar
# Usage: draw_progress_bar <current> <total> [bar_length] [prefix]
draw_progress_bar() {
    local current=$1
    local total=$2
    local bar_length=${3:-50}  # Default bar length of 50 characters
    local prefix=${4:-"Progress"}

    # Calculate percentage
    local percentage=$((current * 100 / total))
    local filled_length=$((current * bar_length / total))

    # Create the progress bar
    local bar=""
    for ((i=0; i<filled_length; i++)); do
        bar+="█"
    done
    for ((i=filled_length; i<bar_length; i++)); do
        bar+="░"
    done

    # Print the progress bar (overwrite previous line)
    printf "\r${BLUE}%s${NC}: [%s] %d%% (%d/%d)" "$prefix" "$bar" "$percentage" "$current" "$total"

    # Add newline when complete
    if [ "$current" -eq "$total" ]; then
        printf "\n${GREEN}✓ Complete!${NC}\n"
    fi
}

# Function to monitor file copy progress using pv (pipe viewer)
# Usage: copy_with_progress <source> <destination>
copy_with_progress() {
    local source="$1"
    local destination="$2"

    if [ ! -f "$source" ]; then
        echo -e "${RED}Error: Source file '$source' not found${NC}"
        return 1
    fi

    if command -v pv >/dev/null 2>&1; then
        echo -e "${BLUE}Copying: $(basename "$source")${NC}"
        pv "$source" > "$destination"
        echo -e "${GREEN}✓ Copy completed${NC}"
    else
        echo -e "${YELLOW}Warning: 'pv' not installed. Using basic copy...${NC}"
        cp "$source" "$destination"
        echo -e "${GREEN}✓ Copy completed${NC}"
    fi
}

# Function to copy multiple files with progress
# Usage: copy_files_with_progress <source_dir> <dest_dir> [file_pattern]
copy_files_with_progress() {
    local source_dir="$1"
    local dest_dir="$2"
    local pattern="${3:-*}"

    if [ ! -d "$source_dir" ]; then
        echo -e "${RED}Error: Source directory '$source_dir' not found${NC}"
        return 1
    fi

    mkdir -p "$dest_dir"

    # Count total files
    local total_files=$(find "$source_dir" -name "$pattern" -type f | wc -l)

    if [ "$total_files" -eq 0 ]; then
        echo -e "${YELLOW}No files matching pattern '$pattern' found${NC}"
        return 0
    fi

    echo -e "${BLUE}Copying $total_files files from $source_dir to $dest_dir${NC}"

    local current=0
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        local relative_path="${file#$source_dir/}"
        local dest_file="$dest_dir/$relative_path"

        # Create destination directory if needed
        mkdir -p "$(dirname "$dest_file")"

        # Copy file
        cp "$file" "$dest_file"

        ((current++))
        draw_progress_bar "$current" "$total_files" 40 "Copying files"
    done < <(find "$source_dir" -name "$pattern" -type f -print0)
}

# Function to monitor compression progress
# Usage: compress_with_progress <source_file> [compression_type]
compress_with_progress() {
    local source="$1"
    local comp_type="${2:-gz}"  # Default to gzip

    if [ ! -f "$source" ]; then
        echo -e "${RED}Error: Source file '$source' not found${NC}"
        return 1
    fi

    local output_file=""
    local compress_cmd=""

    case "$comp_type" in
        "gz"|"gzip")
            output_file="${source}.gz"
            if command -v pv >/dev/null 2>&1; then
                compress_cmd="pv \"$source\" | gzip > \"$output_file\""
            else
                compress_cmd="gzip -c \"$source\" > \"$output_file\""
            fi
            ;;
        "bz2"|"bzip2")
            output_file="${source}.bz2"
            if command -v pv >/dev/null 2>&1; then
                compress_cmd="pv \"$source\" | bzip2 > \"$output_file\""
            else
                compress_cmd="bzip2 -c \"$source\" > \"$output_file\""
            fi
            ;;
        "xz")
            output_file="${source}.xz"
            if command -v pv >/dev/null 2>&1; then
                compress_cmd="pv \"$source\" | xz > \"$output_file\""
            else
                compress_cmd="xz -c \"$source\" > \"$output_file\""
            fi
            ;;
        *)
            echo -e "${RED}Error: Unsupported compression type '$comp_type'${NC}"
            return 1
            ;;
    esac

    echo -e "${BLUE}Compressing: $(basename "$source") with $comp_type${NC}"
    eval "$compress_cmd"
    echo -e "${GREEN}✓ Compression completed: $(basename "$output_file")${NC}"
}

# Function to monitor file download progress (requires curl or wget)
# Usage: download_with_progress <url> [output_file]
download_with_progress() {
    local url="$1"
    local output="${2:-$(basename "$url")}"

    if command -v curl >/dev/null 2>&1; then
        echo -e "${BLUE}Downloading: $url${NC}"
        curl -L --progress-bar -o "$output" "$url"
        echo -e "${GREEN}✓ Download completed: $output${NC}"
    elif command -v wget >/dev/null 2>&1; then
        echo -e "${BLUE}Downloading: $url${NC}"
        wget --progress=bar:force -O "$output" "$url" 2>&1
        echo -e "${GREEN}✓ Download completed: $output${NC}"
    else
        echo -e "${RED}Error: Neither curl nor wget is installed${NC}"
        return 1
    fi
}

# Function to create a backup with progress
# Usage: backup_with_progress <source_dir> <backup_name>
backup_with_progress() {
    local source_dir="$1"
    local backup_name="${2:-backup_$(date +%Y%m%d_%H%M%S)}"

    if [ ! -d "$source_dir" ]; then
        echo -e "${RED}Error: Source directory '$source_dir' not found${NC}"
        return 1
    fi

    local backup_file="${backup_name}.tar.gz"

    echo -e "${BLUE}Creating backup: $backup_file${NC}"

    if command -v pv >/dev/null 2>&1; then
        # Use pv to show progress
        tar cf - "$source_dir" | pv -s $(du -sb "$source_dir" | awk '{print $1}') | gzip > "$backup_file"
    else
        # Fallback without progress
        echo -e "${YELLOW}Creating backup without progress indicator...${NC}"
        tar czf "$backup_file" "$source_dir"
    fi

    echo -e "${GREEN}✓ Backup completed: $backup_file${NC}"
}

# Function to simulate a long-running process with progress bar
# Usage: simulate_process [duration_seconds] [steps]
simulate_process() {
    local duration=${1:-10}
    local steps=${2:-100}
    local step_delay=$(echo "scale=2; $duration / $steps" | bc -l 2>/dev/null || echo "0.1")

    echo -e "${BLUE}Simulating process...${NC}"

    for ((i=1; i<=steps; i++)); do
        sleep "$step_delay"
        draw_progress_bar "$i" "$steps" 50 "Processing"
    done
}

# Function to check disk usage with visual bar
# Usage: show_disk_usage [path]
show_disk_usage() {
    local path="${1:-.}"

    echo -e "${BLUE}Disk usage for: $path${NC}"

    # Get disk usage information
    local usage_info=$(df -h "$path" | tail -1)
    local used=$(echo "$usage_info" | awk '{print $3}' | sed 's/[^0-9.]//g')
    local total=$(echo "$usage_info" | awk '{print $2}' | sed 's/[^0-9.]//g')
    local percentage=$(echo "$usage_info" | awk '{print $5}' | sed 's/%//')

    # Create visual representation
    local bar_length=50
    local filled=$((percentage * bar_length / 100))

    local bar=""
    for ((i=0; i<filled; i++)); do
        if [ "$percentage" -gt 80 ]; then
            bar+="${RED}█${NC}"
        elif [ "$percentage" -gt 60 ]; then
            bar+="${YELLOW}█${NC}"
        else
            bar+="${GREEN}█${NC}"
        fi
    done

    for ((i=filled; i<bar_length; i++)); do
        bar+="░"
    done

    printf "Usage: [%s] %d%% (%s/%s)\n" "$bar" "$percentage" "${used}G" "${total}G"
}

# Example usage function
show_examples() {
    cat << 'EOF'
Progress Bar Functions - Usage Examples:

1. Basic progress bar:
   draw_progress_bar 25 100 50 "Loading"

2. Copy file with progress:
   copy_with_progress "/path/to/source.txt" "/path/to/dest.txt"

3. Copy multiple files:
   copy_files_with_progress "/source/dir" "/dest/dir" "*.txt"

4. Compress file:
   compress_with_progress "/path/to/file.txt" "gz"

5. Download file:
   download_with_progress "https://example.com/file.zip"

6. Create backup:
   backup_with_progress "/important/data" "my_backup"

7. Simulate process:
   simulate_process 5 50

8. Show disk usage:
   show_disk_usage "/home"

Requirements:
- pv (pipe viewer): sudo apt install pv  # For enhanced progress display
- bc: sudo apt install bc              # For calculations
- curl or wget: For downloads
EOF
}

# cp_with_monitoring() {
#     local source="$1"
#     local destination="$2"
#     local monitor_interval="${3:-1}"  # Check every N seconds

#     echo "DESTINATION: $destination"

#     if [ ! -f "$source" ]; then
#         echo -e "${RED}Error: Source file not found${NC}"
#         return 1
#     fi

#     local source_size=$(stat -f%z "$source" 2>/dev/null || stat -c%s "$source" 2>/dev/null)

#     echo -e "${BLUE}Method 4: Monitoring cp in background${NC}"
#     echo "Source file size: $(numfmt --to=iec-i --suffix=B $source_size)"
#     echo "Starting copy..."

#     # Start cp in background
#     cp "$source" "$destination" &
#     local cp_pid=$!

#     # Monitor progress
#     while kill -0 $cp_pid 2>/dev/null; do
#         echo "Looping..."
#         if [ -f "$destination" ] || [ -d "$destination" ]; then
#             echo "Calculating..."
#             local current_size=$(stat -f%z "$destination" 2>/dev/null || stat -c%s "$destination" 2>/dev/null)
#             local percentage=$((current_size * 100 / source_size))
#             local current_human=$(numfmt --to=iec-i --suffix=B $current_size)
#             local total_human=$(numfmt --to=iec-i --suffix=B $source_size)

#             printf "\rProgress: %s / %s (%d%%)" "$current_human" "$total_human" "$percentage"
#         fi
#         sleep "$monitor_interval"
#     done

#     echo "waiting..."
#     wait $cp_pid
#     echo -e "\n${GREEN}✓ Copy completed${NC}"
# }

copy_file_with_basic_monitoring() {
    local source="$1"
    if ! [ -f "$source" ]; then
        echo "Source is NOT a file or does not exist: $source"
        exit 1
    fi

    local destination="$2"
    if ! [ -e "$destination" ]; then
        echo "Destination does not exist: $destination"
        exit 1
    fi

    local source_size
    local current_size
    source_size=$(size_of "$source")
    current_size=$(size_of "$destination")
    local percentage=$((current_size * 100 / source_size))

    # echo "Source size: $(numfmt --to=iec-i --suffix=B $source_size)"
    # echo "Starting copy..."

    # Start cp in background
    cp "$source" "$destination" &
    local cp_pid=$!

    # Monitor progress
    while kill -0 $cp_pid 2>/dev/null; do
        current_size=$(size_of "$destination")
        percentage=$((current_size * 100 / source_size))
        printf "\rProgress: %s / %s (%d%%)" \
               "$(numfmt --to=iec-i --suffix=B "$current_size")" \
               "$(numfmt --to=iec-i --suffix=B "$source_size")" \
               "$percentage"
        sleep 1
    done

    wait $cp_pid
    echo -e "\n${GREEN}✓ File copy completed${NC}"
}

# # If script is run directly, show examples
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     show_examples
# fi
# draw_progress_bar 25 100 50 "Loading"
echo "Copying file with progress:"
copy_file "/run/media/rmayobre/Ryan SD/Games/wow-3.3.5a/Data/patch-2.MPQ" "/run/media/rmayobre/Ryan SD/test/"
# copy_with_progress "./text.txt" "./test/text2.txt"

# echo "Copying multiple files:"
# copy_files_with_progress "./" "./test"

# # 4. Compress file:
# compress_with_progress "./index.html" "gz"

# # 5. Download file:
# download_with_progress "https://github.com/rmayobre/shtuff/blob/main/assets/logo.png"

# # 6. Create backup:
# backup_with_progress "./assets" "my_assets"

# # 7. Simulate process:
# simulate_process 5 50

# 8. Show disk usage:
# show_disk_usage "/home"
