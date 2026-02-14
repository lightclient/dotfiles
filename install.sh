#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Dotfiles installer — detects OS and installs packages + symlinks
# ==============================================================================

# --- Common packages across all platforms ---
# These are the canonical names; mapped to platform-specific names below.
PACKAGES=(
  # Shell & prompt
  zsh
  starship
  tmux
  zsh-autosuggestions

  # Modern CLI tools
  ripgrep
  fd
  fzf
  eza
  bat
  zoxide
  jq
  tldr
  # Git
  git
  git-delta
  lazygit
  gh

  # Editors
  neovim

  # Languages & toolchains
  go
  rustup

  # Node
  fnm

  # Python
  uv

  # Dev tools
  stylua
  prettier
)

# --- Platform detection ---
detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          ubuntu|debian|pop|linuxmint) echo "debian" ;;
          fedora|rhel|centos|rocky|alma) echo "fedora" ;;
          arch|manjaro|endeavouros) echo "arch" ;;
          *) echo "unknown" ;;
        esac
      else
        echo "unknown"
      fi
      ;;
    *) echo "unknown" ;;
  esac
}

# --- Package name mappings (when they differ from canonical name) ---
# Format: map_<platform>_<canonical>=<platform-specific-name>
# If no mapping exists, the canonical name is used.

# macOS (brew)
map_macos_fd="fd"
map_macos_git_delta="git-delta"
map_macos_neovim="neovim"
map_macos_tldr="tldr"

# Debian/Ubuntu (apt)
map_debian_fd="fd-find"
map_debian_bat="bat"
map_debian_ripgrep="ripgrep"
map_debian_git_delta=""          # not in apt, installed separately
map_debian_lazygit=""            # not in apt, installed separately
map_debian_eza=""                # not in apt, installed separately
map_debian_starship=""           # not in apt, installed separately
map_debian_zoxide=""             # not in apt, installed separately
map_debian_zsh_autosuggestions="zsh-autosuggestions"
map_debian_neovim=""             # apt version too old, installed separately
map_debian_fnm=""                # not in apt, installed separately
map_debian_stylua=""             # not in apt, installed separately
map_debian_prettier=""           # not in apt, installed separately
map_debian_uv=""                 # not in apt, installed separately
map_debian_go="golang"
map_debian_tldr="tldr"

# Fedora (dnf)
map_fedora_fd="fd-find"
map_fedora_git_delta=""          # installed separately
map_fedora_lazygit=""            # installed separately
map_fedora_starship=""           # installed separately
map_fedora_fnm=""                # installed separately
map_fedora_uv=""                 # installed separately
map_fedora_stylua=""             # installed separately
map_fedora_prettier=""           # installed separately
map_fedora_neovim="neovim"
map_fedora_go="golang"
map_fedora_tldr="tldr"

# Arch (pacman)
map_arch_git_delta="git-delta"
map_arch_go="go"
map_arch_tldr="tldr"

get_pkg_name() {
  local platform="$1"
  local pkg="$2"
  local safe_pkg="${pkg//-/_}"
  local var="map_${platform}_${safe_pkg}"
  echo "${!var:-$pkg}"
}

# --- Installers ---
install_macos() {
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  local to_install=()
  for pkg in "${PACKAGES[@]}"; do
    local name
    name=$(get_pkg_name macos "$pkg")
    if ! brew list "$name" &>/dev/null; then
      to_install+=("$name")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installing: ${to_install[*]}"
    brew install "${to_install[@]}"
  else
    echo "All packages already installed."
  fi
}

install_debian() {
  echo "Updating apt..."
  sudo apt-get update -qq

  local to_install=()
  for pkg in "${PACKAGES[@]}"; do
    local name
    name=$(get_pkg_name debian "$pkg")
    [ -z "$name" ] && continue  # skip packages that need special install
    if ! dpkg -l "$name" &>/dev/null; then
      to_install+=("$name")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installing: ${to_install[*]}"
    sudo apt-get install -y "${to_install[@]}"
  fi

  # Packages not available via apt — install from GitHub releases / install scripts
  install_from_cargo delta git-delta
  install_from_cargo eza eza
  install_from_cargo zoxide zoxide
  install_from_cargo stylua stylua
  install_uv
  install_starship
  install_fnm
  install_neovim_appimage
  install_lazygit_github
  command -v prettier &>/dev/null || npm install -g prettier 2>/dev/null || true
}

install_fedora() {
  local to_install=()
  for pkg in "${PACKAGES[@]}"; do
    local name
    name=$(get_pkg_name fedora "$pkg")
    [ -z "$name" ] && continue
    if ! rpm -q "$name" &>/dev/null; then
      to_install+=("$name")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installing: ${to_install[*]}"
    sudo dnf install -y "${to_install[@]}"
  fi

  install_from_cargo delta git-delta
  install_from_cargo stylua stylua
  install_uv
  install_starship
  install_fnm
  install_lazygit_github
  command -v prettier &>/dev/null || npm install -g prettier 2>/dev/null || true
}

install_arch() {
  local to_install=()
  for pkg in "${PACKAGES[@]}"; do
    local name
    name=$(get_pkg_name arch "$pkg")
    if ! pacman -Qi "$name" &>/dev/null 2>&1; then
      to_install+=("$name")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installing: ${to_install[*]}"
    sudo pacman -S --noconfirm "${to_install[@]}"
  fi
}

# --- Helper installers for packages not in system repos ---
install_uv() {
  command -v uv &>/dev/null && return
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
}

install_starship() {
  command -v starship &>/dev/null && return
  echo "Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y
}

install_fnm() {
  command -v fnm &>/dev/null && return
  echo "Installing fnm..."
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
}

install_neovim_appimage() {
  command -v nvim &>/dev/null && return
  echo "Installing Neovim (appimage)..."
  curl -fsSL -o /tmp/nvim.appimage https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
  chmod +x /tmp/nvim.appimage
  sudo mv /tmp/nvim.appimage /usr/local/bin/nvim
}

install_lazygit_github() {
  command -v lazygit &>/dev/null && return
  echo "Installing lazygit..."
  local version
  version=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r '.tag_name' | tr -d 'v')
  local arch
  arch=$(uname -m)
  [ "$arch" = "x86_64" ] && arch="x86_64"
  [ "$arch" = "aarch64" ] && arch="arm64"
  curl -fsSL -o /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${version}_Linux_${arch}.tar.gz"
  tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
  sudo mv /tmp/lazygit /usr/local/bin/
}

install_from_cargo() {
  local cmd="$1"
  local crate="$2"
  command -v "$cmd" &>/dev/null && return
  if command -v cargo &>/dev/null; then
    echo "Installing $crate via cargo..."
    cargo install "$crate"
  else
    echo "SKIP: $crate (cargo not available)"
  fi
}

# --- fzf-tab (git clone, no package available) ---
install_fzf_tab() {
  if [ ! -d "$HOME/.zsh/fzf-tab" ]; then
    echo "Installing fzf-tab..."
    mkdir -p "$HOME/.zsh"
    git clone https://github.com/Aloxaf/fzf-tab "$HOME/.zsh/fzf-tab"
  fi
}

# --- Symlink dotfiles ---
link_dotfiles() {
  echo ""
  echo "Linking dotfiles..."
  local dotfiles_dir
  dotfiles_dir="$(cd "$(dirname "$0")" && pwd)"

  local links=(
    "shell/.zshrc:$HOME/.zshrc"
    "shell/.tmux.conf:$HOME/.tmux.conf"
    "shell/.gitconfig:$HOME/.gitconfig"
    "shell/.config/starship.toml:$HOME/.config/starship.toml"
    "shell/.gnupg/gpg-agent.conf:$HOME/.gnupg/gpg-agent.conf"
    "shell/.ssh/config:$HOME/.ssh/config"
    "editor/.config/nvim:$HOME/.config/nvim"
  )

  for link in "${links[@]}"; do
    local src="${dotfiles_dir}/${link%%:*}"
    local dst="${link##*:}"

    if [ ! -e "$src" ]; then
      echo "  SKIP: $src (not found)"
      continue
    fi

    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ]; then
      rm "$dst"
    elif [ -e "$dst" ]; then
      echo "  BACKUP: $dst -> ${dst}.bak"
      mv "$dst" "${dst}.bak"
    fi

    ln -sf "$src" "$dst"
    echo "  ${dst} -> ${src}"
  done
}

# --- Main ---
main() {
  local platform
  platform=$(detect_platform)
  echo "Detected platform: $platform"
  echo ""

  case "$platform" in
    macos)  install_macos ;;
    debian) install_debian ;;
    fedora) install_fedora ;;
    arch)   install_arch ;;
    *)
      echo "Unsupported platform. Install packages manually:"
      echo "  ${PACKAGES[*]}"
      ;;
  esac

  install_fzf_tab
  link_dotfiles

  echo ""
  echo "Done! Restart your shell or run: exec zsh"
}

main "$@"
