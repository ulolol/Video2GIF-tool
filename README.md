# Video to GIF Creator TUI

<p align="center">
<img src="Video2GIF-tool_logo.gif" alt="Logo" width="300"/>
</p>

This project contains a simple BASH-based Text User Interface (TUI) to create high-quality GIFs from video files.

It's designed for developers who want a quick way to generate GIFs for embedding in GitHub READMEs or other web documentation.

> This came into being, because I myself needed a simple tool to generate DEMO GIFs for GitHub 🔄   
> Sharing it for anyone who finds it useful 😄

## Features

- **Interactive File Selection**: Uses `fzf` (command-line fuzzy finder) to provide a smooth, interactive TUI for browsing and selecting video files.
- **High-Quality GIFs**: Implements a two-pass `ffmpeg` encoding process. It first generates a custom color palette based on the source video and then uses that palette to create a GIF with optimized colors and minimal dithering.
- **Customizable Output**: Allows you to set the **FPS** (frames per second) and **width** of the output GIF.
- **Simple & Portable**: It's a single BASH script with only two common dependencies.

## Demo

![Demo](Video2GIF-tool_github.gif)

## Dependencies

You must have the following command-line tools installed to run this script:

1.  **`ffmpeg`**: The core utility for video and audio conversion.
2.  **`fzf`**: A command-line fuzzy finder used for the file selection TUI.
3.  **`ffprobe`**: Part of the ffmpeg suite, used to probe video metadata.
4.  **`gifsicle`** (optional): Used to optimize the output GIF for smaller file sizes.

### Installation


- **On Arch Linux:**
  ```bash
  sudo pacman -S ffmpeg fzf gifsicle
  ```

- **On Debian/Ubuntu:**
  ```bash
  sudo apt update
  sudo apt install ffmpeg fzf gifsicle
  ```

- **On Fedora:**
  ```bash
  sudo dnf install ffmpeg fzf gifsicle
  ```


- **On macOS (using Homebrew):**
  ```bash
  brew install ffmpeg fzf gifsicle
  ```

## How to Use

1.  **Make the script executable:**
    ```bash
    chmod +x gif-creator.sh
    ```

2.  **Run the script:**
    You can run the script from any directory.
    ```bash
    ./gif-creator.sh
    ```

3.  **Select a Video**:
    The TUI will launch, starting in your `$HOME` directory.
    *   Use the arrow keys (or type to filter) to navigate.
    *   Select `..` to go up to the parent directory.
    *   Select a directory (indicated by a trailing `/`) to enter it.
    *   Select a video file (e.g., `.mp4`, `.mkv`) and press `Enter`. The TUI will automatically detect video files and prompt you if you select a non-video file.


4.  **Done!**
    The script will run the two-pass conversion and save the final GIF in the same directory as the source video, with `_github.gif` appended to its name.

    Example: `my_awesome_video.mp4` -> `my_awesome_video_github.gif`
