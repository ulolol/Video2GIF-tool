#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

APP_NAME="GIF Creator TUI"

show_usage() {
    cat <<'EOF'
Usage: gif-creator.sh [START_DIR]

Starts an interactive TUI for browsing video files and generating optimized GIFs.
If START_DIR is omitted, the script starts from the current user's home directory.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_usage
    exit 0
fi

START_DIR="${1:-$HOME}"
if [[ ! -d "$START_DIR" ]]; then
    echo "Error: Starting directory '$START_DIR' does not exist." >&2
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: 'ffmpeg' is not installed. Please install it to use this script." >&2
    exit 1
fi

if ! command -v fzf &> /dev/null; then
    echo "Error: 'fzf' (fuzzy finder) is not installed. Please install it for the file selection TUI." >&2
    exit 1
fi

if ! command -v ffprobe &> /dev/null; then
    echo "Error: 'ffprobe' is not installed. Please install it to inspect video metadata." >&2
    exit 1
fi

if command -v gifsicle &> /dev/null; then
    GIFSICLE_AVAILABLE=true
else
    echo "Warning: 'gifsicle' is not installed. GIF optimization will be skipped. Install 'gifsicle' for smaller output files." >&2
    GIFSICLE_AVAILABLE=false
fi


CURRENT_DIR="$START_DIR"
VIDEO_FILE=""
VALID_EXTENSIONS='\.(mp4|mkv|mov|webm|avi|flv)$'
FPS_DEFAULT=15
VIDEO_WIDTH=800
VIDEO_HEIGHT=-1
MAX_WIDTH=1280
MAX_HEIGHT=720
CHUNK_SECONDS=30

probe_video_defaults() {
    local file="$1"
    local rate width_value height_value

    if rate=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$file"); then
        if [[ -n "$rate" ]]; then
            FPS_DEFAULT=$(awk -F'/' '{den=($2==""?1:$2); if(den==0) den=1; printf("%.0f", $1/den)}' <<< "$rate")
            if [[ $FPS_DEFAULT -le 0 ]]; then
                FPS_DEFAULT=15
            fi
        fi
    fi

    local raw_width raw_height
    raw_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$file")
    raw_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$file")

    if [[ "$raw_width" =~ ^[1-9][0-9]*$ ]] && [[ "$raw_height" =~ ^[1-9][0-9]*$ ]]; then
        # Calculate scaled dimensions preserving aspect ratio using awk
        IFS=' ' read -r VIDEO_WIDTH VIDEO_HEIGHT <<< $(awk -v w="$raw_width" -v h="$raw_height" -v mw="$MAX_WIDTH" -v mh="$MAX_HEIGHT" '
        BEGIN {
            nw = w; nh = h;
            if (nw > mw) { factor = mw/nw; nw = mw; nh = h * factor; }
            if (nh > mh) { factor = mh/nh; nh = mh; nw = nw * factor; }
            printf "%.0f %.0f", nw, nh
        }')
    fi
}

get_video_duration_seconds() {
    local file="$1"
    local duration_line duration_seconds

    if duration_line=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file"); then
        duration_seconds=$(awk -v d="$duration_line" 'BEGIN{if(d<=0) d=0; printf("%.0f", d)}')
    else
        duration_seconds=0
    fi

    printf '%s' "$duration_seconds"
}

printf "🚀  Starting %s...\n" "$APP_NAME"
printf "Searching for video files in %s and its subdirectories.\n" "$CURRENT_DIR"
printf "Press Ctrl+C or Esc to exit.\n"

while true; do
    ITEMS=$( (cd "$CURRENT_DIR" && ls -ap) )
    REL_PATH="${CURRENT_DIR#$START_DIR}"
    REL_PATH=${REL_PATH#/}
    if [[ -z "$REL_PATH" ]]; then
        PROMPT_DIR="$(basename "$START_DIR")"
    else
        PROMPT_DIR="$(basename "$START_DIR")/$REL_PATH"
    fi

    SELECTION=$(printf "..\n%s" "$ITEMS" | fzf --prompt="▶ $PROMPT_DIR/ " --height="50%" --border --reverse --no-info)

    if [[ -z "$SELECTION" ]]; then
        echo "No file selected. Exiting."
        exit 0
    fi

    if [[ "$SELECTION" == ".." ]]; then
        if [[ "$CURRENT_DIR" != "/" ]]; then
            CURRENT_DIR=$(dirname "$CURRENT_DIR")
        fi
        continue
    fi

    FULL_PATH="$(realpath "$CURRENT_DIR/$SELECTION")"

    if [[ "$SELECTION" == */ ]]; then
        if [[ -d "$FULL_PATH" ]]; then
            CURRENT_DIR="$FULL_PATH"
        fi
        continue
    fi

    if [[ -f "$FULL_PATH" ]]; then
        if [[ "$FULL_PATH" =~ $VALID_EXTENSIONS ]]; then
            VIDEO_FILE="$FULL_PATH"
            break
        fi

        echo "Selected file is not a recognized video format: $SELECTION"
        sleep 1
    fi

done

if [[ -z "$VIDEO_FILE" ]]; then
    echo "No video file chosen. Exiting." >&2
    exit 1
fi

probe_video_defaults "$VIDEO_FILE"


printf '%s\n' '----------------------------------------'
printf "Selected Video: %s\n" "$VIDEO_FILE"
printf "Detected FPS:   %s\n" "$FPS_DEFAULT"
printf "Detected Size:  %sx%s\n" "$VIDEO_WIDTH" "$VIDEO_HEIGHT"
printf '%s\n' '----------------------------------------'

FPS="15"
WIDTH="800"
HEIGHT="-1"
OUTPUT_GIF="${VIDEO_FILE%.*}_github.gif"

printf '%s\n' '----------------------------------------'
printf "Input:    %s\n" "$VIDEO_FILE"
printf "Output:   %s\n" "$OUTPUT_GIF"
printf "FPS:      %s\n" "$FPS"
printf "Width:    %s\n" "$WIDTH"
printf "Height:   %s\n" "$HEIGHT"
printf '%s\n' '----------------------------------------'

TEMP_PALETTE_FILE=$(mktemp --dry-run .XXXXXXXXXX.png)
cleanup_palette() {
    [[ -f "$TEMP_PALETTE_FILE" ]] && rm -f "$TEMP_PALETTE_FILE"
}
trap cleanup_palette EXIT

printf "⏳  Converting video to optimized GIF...
"
ffmpeg -y -i "$VIDEO_FILE" -vf "fps=$FPS,scale=$WIDTH:$HEIGHT:flags=lanczos,palettegen" "$TEMP_PALETTE_FILE" && \
    ffmpeg -y -i "$VIDEO_FILE" -i "$TEMP_PALETTE_FILE" -filter_complex "fps=$FPS,scale=$WIDTH:$HEIGHT:flags=lanczos[x];[x][1:v]paletteuse" "$OUTPUT_GIF"

if $GIFSICLE_AVAILABLE; then
    printf "⏳  Optimizing GIF with gifsicle...\n"
    gifsicle -O3 "$OUTPUT_GIF" -o "$OUTPUT_GIF"
fi

printf "\n✅  Success! High-quality GIF created at:\n"
printf "   -> %s\n\n" "$OUTPUT_GIF"
printf "You can now embed it in your GitHub README.\n"
