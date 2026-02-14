# dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Structure

```
dotfiles/
├── shell/          # zsh, tmux, git, starship, gpg, ssh, pi
├── editor/         # neovim
├── gui/            # alacritty, sway, i3status-rust (linux)
└── install.sh      # multi-OS installer
```

Each top-level directory is a stow package. Files inside mirror the home
directory structure — `shell/.zshrc` becomes `~/.zshrc`, `editor/.config/nvim`
becomes `~/.config/nvim`, etc.

## Install

```bash
git clone git@github.com:lightclient/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The install script detects your OS (macOS, Debian/Ubuntu, Fedora, Arch),
installs packages, symlinks configs with stow, and sets up
[pi](https://github.com/mariozechner/pi-coding-agent).

## What's included

### Shell
- **zsh** with vi mode, history search (`^P`/`^N`), `jk` to escape
- **[starship](https://starship.rs)** prompt — minimal, single-line
- **[tmux](https://github.com/tmux/tmux)** config
- **[fzf](https://github.com/junegunn/fzf)** with bat previews
- **[fzf-tab](https://github.com/Aloxaf/fzf-tab)** for fuzzy tab completion
- **[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)**
- **[zoxide](https://github.com/ajeetdsouza/zoxide)** smarter `cd`
- **[bat](https://github.com/sharkdp/bat)** aliased to `cat`
- **[eza](https://github.com/eza-community/eza)** aliased to `ls`
- **[delta](https://github.com/dandavison/delta)** for git diffs
- GPG/SSH agent integration

### Editor
- **[Neovim](https://neovim.io)** based on kickstart.nvim
- **[blink.cmp](https://github.com/saghen/blink.cmp)** for autocompletion
- **[Telescope](https://github.com/nvim-telescope/telescope.nvim)** fuzzy finder (`<C-p>` files, `<C-g>` grep)
- LSP support for Go, Lua, Rust, Markdown (auto-installed via Mason)
- Themes: tokyonight, catppuccin, rose-pine, nightfox (`<leader>sc` to switch)
- Git integration via gitsigns + fugitive

### GUI (Linux)
- Sway (Wayland compositor)
- Alacritty terminal
- i3status-rust

## Adding a new stow package

```bash
mkdir -p newpkg/.config/foo
# add files mirroring ~/
stow newpkg -t ~
```

## License

MIT
