# ytd & yts 🎬

> Fast, interactive YouTube video search & downloader with animated progress bars for Zsh.

`ytd` and `yts` bring keyboard-driven YouTube search and downloading straight to your terminal, powered by `yt-dlp` and `fzf`.

---

## ✨ Features

- **Terminal Search (`yts`)**: Search YouTube with `@channel` or search keywords. Select results interactively with `fzf` displaying duration, title, and uploader. Automatically copies the video URL to your clipboard (Wayland, X11, macOS) and prompts for immediate download.
- **Smart Downloader (`ytd`)**:
  - Direct URL download or interactive keyword search on the fly.
  - Interactive destination folder picker in your video directory using `fzf`.
  - Automatic optimal subtitle extraction (prioritizes creator-uploaded manual subtitles matching the video's spoken language, then English, with fallback to automatic captions) converted to `.srt` and embedded into the MP4 container.
  - Concurrent fragment downloading with automated retries.
- **Animated Progress Bars**:
  - `pacman` style: `[───────ᗧ•••ᗤ]  45.2%  12.4MiB/27.4MiB  ↓ 4.8MiB/s`
  - `modern` style: `▕████████░░░░▏ 65.0%  45.1MiB/69.4MiB  ↓ 8.2MiB/s`
- **Smart Browser Cookies**: Automatically searches for existing authenticated session cookies (Brave, Chrome, Chromium, Firefox) so age-restricted or member videos download without interruption.

---

## 📦 Requirements

- **[Zsh](https://www.zsh.org/)** (v5.0+)
- **[yt-dlp](https://github.com/yt-dlp/yt-dlp)**
- **[fzf](https://github.com/junegunn/fzf)**
- **Python 3**
- Clipboard tool: `wl-copy` (Wayland), `xclip` / `xsel` (X11), or `pbcopy` (macOS)

---

## 🚀 Installation

### Using [Zinit](https://github.com/zdharma-continuum/zinit)
```zsh
zinit light viyoga/ytd
```

### Using [Oh My Zsh](https://ohmyz.sh/)
```zsh
git clone https://github.com/viyoga/ytd.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/ytd
```
Then add `ytd` to your plugin array in `~/.zshrc`:
```zsh
plugins=(... ytd)
```

### Manual Installation
Clone the repository:
```bash
git clone https://github.com/viyoga/ytd.git ~/.config/zsh/plugins/ytd
```
Source it in your `~/.zshrc`:
```zsh
source ~/.config/zsh/plugins/ytd/ytd.zsh
```

---

## 🕹️ Usage

### Quick Search (`yts`)
```bash
# Search by keyword
yts lo-fi hip hop chill beats

# Search a channel directly
yts @Fireship

# Interactive prompt if called without arguments
yts
```

### Video Downloader (`ytd`)
```bash
# Direct link
ytd "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Search and download in one step
ytd veritasium pyramids

# Interactive prompt
ytd
```

---

## ⚙️ Configuration

Set any of these optional environment variables in your `~/.zshrc`:

```zsh
# Default download destination folder (default: $HOME/Videos)
export YTD_DIR="$HOME/Videos"

# Progress bar theme: "pacman" (default) or "modern"
export YTD_BAR_STYLE="pacman"

# Browser cookies override (e.g., "firefox", "brave", "chrome")
# export YTD_COOKIES="brave"
```

---

## 📄 License

[MIT](LICENSE) © [viyoga](https://github.com/viyoga)
