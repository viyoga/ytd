# ==============================================================================
#  ytd & yts — Interactive YouTube Downloader & Terminal Search for Zsh
# ==============================================================================

# Helper: Detect installed browser cookie store (override with export YTD_COOKIES="...")
_ytd_detect_cookies() {
    if [[ -n "$YTD_COOKIES" ]]; then
        echo "$YTD_COOKIES"
        return 0
    fi

    local -a candidates=(
        "brave+gnomekeyring:$HOME/.config/BraveSoftware/Brave-Origin-Nightly/Default"
        "brave+gnomekeyring:$HOME/.config/BraveSoftware/Brave-Browser/Default"
        "brave:$HOME/.config/BraveSoftware/Brave-Browser/Default"
        "chrome+gnomekeyring:$HOME/.config/google-chrome/Default"
        "chrome:$HOME/.config/google-chrome/Default"
        "chromium+gnomekeyring:$HOME/.config/chromium/Default"
        "chromium:$HOME/.config/chromium/Default"
        "firefox"
    )

    for cand in "${candidates[@]}"; do
        local p="${cand#*:}"
        if [[ "$cand" == "$p" ]]; then
            if command -v "$cand" >/dev/null 2>&1; then
                echo "$cand"
                return 0
            fi
        elif [[ -d "$p" ]]; then
            echo "$cand"
            return 0
        fi
    done

    return 1
}

# Helper: Cross-platform clipboard copy (Wayland / X11 / macOS)
_ytd_copy_clipboard() {
    local text="$1"
    if command -v wl-copy >/dev/null 2>&1; then
        echo -n "$text" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        echo -n "$text" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        echo -n "$text" | xsel --clipboard --input
    elif command -v pbcopy >/dev/null 2>&1; then
        echo -n "$text" | pbcopy
    fi
}

# Internal helper: Search YouTube (@channel or keywords) and interactively pick with fzf
_ytd_search_picker() {
    local query="$*"
    _YTD_PICKED_URL=""
    _YTD_PICKED_TITLE=""

    if [[ -z "$query" ]]; then
        printf '\033[33mSearch YouTube (@channel / keywords): \033[0m'
        read -r query
        [[ -z "$query" ]] && return 1
    fi

    local target=""
    local count=15
    local yt_args=()

    if [[ "$query" =~ ^@ || "$query" =~ ^https?://.*youtube\.com/(@.*|c/.*|channel/.*) ]]; then
        local ch="${query#@}"
        if [[ ! "$query" =~ ^https?:// ]]; then
            target="https://www.youtube.com/@${ch}/videos"
        else
            target="${query%/}/videos"
        fi
        yt_args=("$target" --playlist-end "$count" --flat-playlist)
    else
        target="ytsearch${count}:${query}"
        yt_args=("$target" --flat-playlist)
    fi

    local tmp_res=$(mktemp)
    yt-dlp "${yt_args[@]}" --print "%(id)s	%(title)s	%(duration_string)s	%(uploader)s" --no-warnings >| "$tmp_res" 2>/dev/null &
    local pid=$!
    trap 'kill $pid 2>/dev/null; rm -f "$tmp_res"; return 1' INT

    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=1
    while kill -0 $pid 2>/dev/null; do
        printf "\r\033[36m%s\033[0m \033[33mSearching YouTube for '%s'...\033[0m" "${spin[$i]}" "$query"
        i=$(( (i % 10) + 1 ))
        sleep 0.08
    done
    wait $pid 2>/dev/null
    trap - INT
    printf "\r\033[K"

    # Parse and format results for fzf
    local formatted=$(python3 -c '
import sys

with open(sys.argv[1]) as f:
    for line in f:
        parts = line.strip().split("\t")
        if len(parts) >= 4:
            vid, title, dur, uploader = parts[0], parts[1], parts[2], parts[3]
            if len(vid) == 11:
                dur_str = f"[{dur}]" if dur and dur != "NA" else "[Video]"
                uploader_str = f"({uploader})" if uploader and uploader != "NA" else ""
                display = f"\033[33m{dur_str:<10}\033[0m \033[1;37m{title}\033[0m \033[90m{uploader_str}\033[0m"
                print(f"{display}\thttps://youtu.be/{vid}\t{title}")
' "$tmp_res" 2>/dev/null)
    rm -f "$tmp_res"

    if [[ -z "$formatted" ]]; then
        echo -e "\033[1;31m✖ No videos found for: $query\033[0m"
        return 1
    fi

    local selected=$(printf "%s\n" "$formatted" | fzf --ansi --delimiter='\t' --with-nth=1 \
        --prompt="Select Video > " \
        --header="Search: $query | [ENTER: Select | ESC: Cancel]" \
        --height=50% --reverse)

    [[ -z "$selected" ]] && return 1

    _YTD_PICKED_URL=$(printf "%s" "$selected" | cut -f2)
    _YTD_PICKED_TITLE=$(printf "%s" "$selected" | cut -f3)
    return 0
}

# Standalone command: Search YouTube, copy URL to clipboard, optionally download with ytd
yts() {
    setopt local_options clobber no_monitor no_notify

    local query="$*"
    _ytd_search_picker "$query" || return 1

    echo -e "\033[1;32m✔ Video:\033[0m \033[1;37m$_YTD_PICKED_TITLE\033[0m"
    echo -e "\033[1;32m✔ URL:\033[0m   \033[1;36m$_YTD_PICKED_URL\033[0m"

    _ytd_copy_clipboard "$_YTD_PICKED_URL"
    echo -e "\033[1;32m✔ Copied link to clipboard!\033[0m"
    echo
    printf '\033[33mDownload with ytd now? [Y/n]: \033[0m'
    local ans
    read -r ans
    if [[ -z "$ans" || "$ans" =~ ^[yY] ]]; then
        ytd "$_YTD_PICKED_URL"
    fi
}

# Interactive & direct YouTube downloader
ytd() {
    setopt local_options clobber no_monitor no_notify

    local input="$*"
    local target_url=""

    # 1. If arguments passed, detect whether URL or search
    if [[ -n "$input" ]]; then
        if [[ "$input" =~ ^https?://(www\.)?(youtube\.com/watch\?|youtu\.be/|youtube\.com/shorts/) ]]; then
            target_url="$input"
        else
            _ytd_search_picker "$input" || return 1
            target_url="$_YTD_PICKED_URL"
        fi
    fi

    # 2. Pick destination folder
    local base_dir="${YTD_DIR:-$HOME/Videos}"
    [[ ! -d "$base_dir" ]] && base_dir="${HOME}/Downloads"
    [[ ! -d "$base_dir" ]] && base_dir="$PWD"

    local dirs=("$(basename "$base_dir") (root)")
    if [[ -d "$base_dir" ]]; then
        for d in "$base_dir"/*/; do
            [[ -d "$d" ]] && dirs+=("$(basename "$d")")
        done
    fi

    local folder=$(printf "%s\n" "${dirs[@]}" | fzf --prompt="Download to > ")
    [[ -z "$folder" ]] && return
    [[ "$folder" == *" (root)" ]] && folder=""
    local dest_dir="$base_dir${folder:+/$folder}"

    echo -e "\033[1;36m❯ Downloading to: $dest_dir\033[0m"

    # 3. If no URL yet, prompt for link, @channel, or keywords
    if [[ -z "$target_url" ]]; then
        printf '\033[33mPaste YouTube link, @channel, or search query: \033[0m'
        read -r input
        [[ -z "$input" ]] && return

        if [[ "$input" =~ ^https?://(www\.)?(youtube\.com/watch\?|youtu\.be/|youtube\.com/shorts/) ]]; then
            target_url="$input"
        else
            _ytd_search_picker "$input" || return 1
            target_url="$_YTD_PICKED_URL"
        fi
    fi

    local url="$target_url"
    echo

    local -a cookie_args=()
    local detected_cookies
    if detected_cookies="$(_ytd_detect_cookies)"; then
        cookie_args=(--cookies-from-browser "$detected_cookies")
    fi

    local meta_tmp=$(mktemp)

    # Fetch video metadata in background with a responsive spinner
    yt-dlp "${cookie_args[@]}" -J "$url" >| "$meta_tmp" 2>/dev/null &
    local pid=$!
    trap 'kill $pid 2>/dev/null; rm -f "$meta_tmp"; return 1' INT

    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=1
    while kill -0 $pid 2>/dev/null; do
        printf "\r\033[36m%s\033[0m \033[33mFetching video metadata & subtitle streams...\033[0m" "${spin[$i]}"
        i=$(( (i % 10) + 1 ))
        sleep 0.1
    done
    wait $pid 2>/dev/null
    trap - INT
    printf "\r\033[K"

    # Parse metadata for title and optimal single subtitle language
    local meta_info=$(python3 -c "
import sys, json
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    title = data.get('title', '')
    vid_lang = data.get('language', '') or ''
    sub = data.get('subtitles', {}) or {}
    acaps = data.get('automatic_captions', {}) or {}
    base = vid_lang.split('-')[0].lower() if vid_lang and vid_lang != 'None' else ''
    chosen_lang = ''

    # 1. Prefer creator-uploaded manual subtitles first
    if sub:
        if base and base in sub:
            chosen_lang = base
        elif vid_lang and vid_lang in sub:
            chosen_lang = vid_lang
        elif 'en' in sub:
            chosen_lang = 'en'
        else:
            for k in sub:
                if base and k.lower().startswith(f'{base}-'):
                    chosen_lang = k
                    break
            if not chosen_lang:
                for k in sub:
                    if k.lower().startswith('en-'):
                        chosen_lang = k
                        break
            if not chosen_lang:
                chosen_lang = list(sub.keys())[0]

    # 2. Check automatic captions if no manual subtitle found
    if not chosen_lang and acaps:
        if base and base != 'en' and base in acaps:
            chosen_lang = base
        elif base and base != 'en' and f'{base}-orig' in acaps:
            chosen_lang = f'{base}-orig'
        elif 'en' in acaps:
            chosen_lang = 'en'
        elif 'en-orig' in acaps:
            chosen_lang = 'en-orig'
        elif base and base in acaps:
            chosen_lang = base
        else:
            for k in acaps:
                if k.lower().endswith('-orig'):
                    chosen_lang = k
                    break
            if not chosen_lang:
                chosen_lang = list(acaps.keys())[0]

    print(f'{title}\t{chosen_lang}')
except Exception:
    print('\t')
" "$meta_tmp" 2>/dev/null)
    rm -f "$meta_tmp"

    local video_title=""
    local chosen_lang=""
    IFS=$'\t' read -r video_title chosen_lang <<< "$meta_info"

    if [[ -n "$video_title" ]]; then
        echo -e "\033[1;32m✔ Video:\033[0m \033[1;37m$video_title\033[0m"
    fi
    if [[ -n "$chosen_lang" ]]; then
        echo -e "\033[1;32m✔ Subtitle language:\033[0m \033[33m$chosen_lang\033[0m"
    else
        echo -e "\033[1;33mℹ Subtitles:\033[0m \033[90mNone available for this video\033[0m"
    fi
    echo

    # Download: animated horizontal progress bar
    local sub_opts=()
    if [[ -n "$chosen_lang" ]]; then
        sub_opts=(--write-subs --write-auto-sub --sub-langs "^${chosen_lang}$" --convert-subs srt --embed-subs)
    fi

    # Progress bar style: "pacman" (ᗧ···ᗤ) or "modern" (▕████░░░░▏)
    local bar_style="${YTD_BAR_STYLE:-pacman}"

    yt-dlp "${cookie_args[@]}" \
        --no-warnings --quiet --progress --newline \
        --progress-template "download:PROG:%(progress._percent)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s|%(progress._speed_str)s" \
        "${sub_opts[@]}" \
        -f "bv*[ext=mp4]+ba[ext=m4a]/best[ext=mp4]/best" \
        --concurrent-fragments 4 --retries 20 --fragment-retries 20 --socket-timeout 30 \
        -P "$dest_dir" "$url" | python3 -c '
import sys

style = "'"$bar_style"'"
width = 24

def draw_bar(pct_raw, downloaded, total, speed):
    try:
        pct = float(pct_raw)
    except:
        return
    pct = max(0.0, min(100.0, pct))
    filled = int(width * pct / 100)
    empty = width - filled

    if style == "pacman":
        trail = "\033[90m─\033[0m"
        if filled <= 0:
            bar = "\033[1;33mᗧ\033[0m" + "\033[90m•\033[0m" * max(0, width - 2) + "\033[1;31mᗤ\033[0m"
        elif filled >= width - 1:
            bar = trail * (width - 1) + "\033[1;32mᗤ\033[0m"
        else:
            bar = trail * (filled - 1) + "\033[1;33mᗧ\033[0m" + "\033[90m•\033[0m" * max(0, empty - 1) + "\033[1;31mᗤ\033[0m"
        bar_box = f"\033[90m[\033[0m{bar}\033[90m]\033[0m"
    else:
        bar = "\033[36m" + "█" * filled + "\033[90m" + "░" * empty + "\033[0m"
        bar_box = f"\033[36m▕\033[0m{bar}\033[36m▏\033[0m"

    dl_str = f"{downloaded.strip()}/{total.strip()}" if total.strip() != "NA" else downloaded.strip()
    spd_str = f"↓ {speed.strip()}" if speed.strip() != "NA" else ""

    sys.stdout.write(f"\r\033[K  {bar_box} \033[1;36m{pct:5.1f}%\033[0m  \033[33m{dl_str:<17}\033[0m  \033[32m{spd_str}\033[0m")
    sys.stdout.flush()

try:
    for line in sys.stdin:
        if line.startswith("PROG:"):
            parts = line[5:].strip().split("|")
            if len(parts) >= 4:
                draw_bar(parts[0], parts[1], parts[2], parts[3])
    print()
except (KeyboardInterrupt, BrokenPipeError):
    pass
'
    local dl_status=$pipestatus[1]
    echo
    if [[ $dl_status -eq 0 ]]; then
        if [[ -n "$chosen_lang" ]]; then
            echo -e "\033[1;32m✔ Subtitles ($chosen_lang) downloaded and embedded\033[0m"
        fi
        echo -e "\033[1;32m✔ Video downloaded successfully\033[0m"
        echo -e "\033[1;36m❯ Stored in: $dest_dir\033[0m"
    else
        echo -e "\033[1;31m✖ Download failed with exit code $dl_status\033[0m"
    fi
}
