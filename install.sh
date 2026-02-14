#!/usr/bin/env bash
set -euo pipefail

# Ensure user-local bins are available in this non-login shell.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

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
  # rustup is intentionally bootstrapped via the official installer (not distro packages)

  # Node
  fnm

  # Python
  uv

  # Dev tools
  stow
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
map_debian_tldr="tealdeer"

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

  # Respect explicit empty mappings (used to skip repo install and use custom installers).
  if [ "${!var+x}" = "x" ]; then
    echo "${!var}"
  else
    echo "$pkg"
  fi
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

install_debian_fallback() {
  local pkg="$1"

  case "$pkg" in
    git-delta)            install_from_cargo delta git-delta ;;
    eza)                  install_from_cargo eza eza ;;
    zoxide)               install_from_cargo zoxide zoxide ;;
    stylua)               install_from_cargo stylua stylua ;;
    uv)                   install_uv ;;
    starship)             install_starship ;;
    fnm)                  install_fnm ;;
    neovim)               install_neovim_appimage ;;
    lazygit)              install_lazygit_github ;;
    prettier)             install_prettier ;;
    tldr)                 install_tldr ;;
    zsh-autosuggestions)  install_zsh_autosuggestions ;;
    *)                    return 1 ;;
  esac
}

install_debian() {
  echo "Updating apt..."
  sudo apt-get update -qq

  local to_install=()
  local deferred=()

  for pkg in "${PACKAGES[@]}"; do
    local name
    name=$(get_pkg_name debian "$pkg")

    # Explicit empty mapping means: install via fallback installer.
    if [ -z "$name" ]; then
      deferred+=("$pkg")
      continue
    fi

    # Package name exists, but may not be available on this specific distro release.
    if ! apt-cache show "$name" &>/dev/null; then
      deferred+=("$pkg")
      continue
    fi

    if ! dpkg -l "$name" &>/dev/null; then
      to_install+=("$name")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installing via apt: ${to_install[*]}"
    sudo apt-get install -y "${to_install[@]}"
  fi

  if [ ${#deferred[@]} -gt 0 ]; then
    echo "Installing via fallback installers: ${deferred[*]}"
    local failed=()
    for pkg in "${deferred[@]}"; do
      if ! install_debian_fallback "$pkg"; then
        failed+=("$pkg")
      fi
    done

    if [ ${#failed[@]} -gt 0 ]; then
      echo "ERROR: Could not install packages: ${failed[*]}" >&2
      return 1
    fi
  fi

  ensure_debian_command_aliases
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
  install_prettier
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
install_rustup_official() {
  if ! command -v rustup &>/dev/null; then
    echo "Installing rustup (official installer)..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  fi

  export PATH="$HOME/.cargo/bin:$PATH"
  [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

  echo "Ensuring Rust stable toolchain..."
  rustup toolchain install stable >/dev/null 2>&1 || true
  rustup default stable >/dev/null
}

ensure_cargo() {
  command -v cargo &>/dev/null && return 0
  install_rustup_official
  command -v cargo &>/dev/null
}

ensure_npm() {
  command -v npm &>/dev/null && return 0

  export PATH="$HOME/.local/share/fnm:$PATH"
  install_fnm

  if command -v fnm &>/dev/null; then
    eval "$(fnm env --shell bash)"
    fnm install --lts
    command -v npm &>/dev/null && return 0
  fi

  return 1
}

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
  export PATH="$HOME/.local/share/fnm:$PATH"
  command -v fnm &>/dev/null && return
  echo "Installing fnm..."
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
}

install_tldr() {
  command -v tldr &>/dev/null && return

  if command -v cargo &>/dev/null || ensure_cargo; then
    echo "Installing tealdeer via cargo..."
    cargo install tealdeer
    return
  fi

  if command -v npm &>/dev/null || ensure_npm; then
    echo "Installing tldr via npm..."
    npm install -g tldr
    return
  fi

  echo "ERROR: unable to install tldr (need cargo or npm)" >&2
  return 1
}

install_prettier() {
  command -v prettier &>/dev/null && return

  if ! ensure_npm; then
    echo "ERROR: npm not available, cannot install prettier" >&2
    return 1
  fi

  echo "Installing prettier..."
  npm install -g prettier
}

install_zsh_autosuggestions() {
  if [ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] ||
     [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] ||
     [ -f "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    return
  fi

  echo "Installing zsh-autosuggestions..."
  mkdir -p "$HOME/.zsh"
  git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.zsh/zsh-autosuggestions"
}

ensure_debian_command_aliases() {
  mkdir -p "$HOME/.local/bin"

  if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi

  if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi
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

  if ! ensure_cargo; then
    echo "ERROR: cargo not available, cannot install $crate" >&2
    return 1
  fi

  echo "Installing $crate via cargo..."
  cargo install "$crate"
}

# --- fzf-tab (git clone, no package available) ---
install_fzf_tab() {
  if [ ! -d "$HOME/.zsh/fzf-tab" ]; then
    echo "Installing fzf-tab..."
    mkdir -p "$HOME/.zsh"
    git clone https://github.com/Aloxaf/fzf-tab "$HOME/.zsh/fzf-tab"
  fi
}

# --- pi coding agent ---
install_pi() {
  if ! command -v pi &>/dev/null; then
    echo "Installing pi coding agent..."
    if ! ensure_npm; then
      echo "ERROR: npm not available, cannot install pi" >&2
      return 1
    fi
    npm install -g @mariozechner/pi-coding-agent
  fi
}

# --- Symlink dotfiles via stow ---
link_dotfiles() {
  echo ""
  echo "Linking dotfiles with stow..."
  local dotfiles_dir
  dotfiles_dir="$(cd "$(dirname "$0")" && pwd)"
  cd "$dotfiles_dir"

  for package in shell editor pi; do
    if [ -d "$package" ]; then
      echo "  stow $package"
      stow -v --adopt "$package" -t "$HOME" 2>&1 | sed 's/^/    /'
    fi
  done

  # Restore any adopted files to repo versions
  git checkout -- . 2>/dev/null || true
}

# --- Main ---
main() {
  local platform
  platform=$(detect_platform)
  echo "Detected platform: $platform"
  echo ""

  case "$platform" in
    macos)
      install_macos
      install_rustup_official
      ;;
    debian)
      install_debian
      install_rustup_official
      ;;
    fedora)
      install_fedora
      install_rustup_official
      ;;
    arch)
      install_arch
      install_rustup_official
      ;;
    *)
      echo "Unsupported platform. Install packages manually:"
      echo "  ${PACKAGES[*]}"
      ;;
  esac

  install_fzf_tab
  link_dotfiles
  install_pi

  echo ""
  echo "Done! Restart your shell or run: exec zsh"
}

main "$@"
