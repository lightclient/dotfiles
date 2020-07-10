contains $fish_user_paths /home/matt/.cargo/bin; or set -Ua fish_user_paths /home/matt/.cargo/bin
contains $fish_user_paths /home/matt/.pyenv/shims; or set -Ua fish_user_paths /home/matt/.pyenv/shims

if type -q exa
	alias ls="exa"
	alias la="exa -la"
else
	echo "exa not installed."
end

if type -q nvim
	alias vim="nvim"
	set EDITOR nvim
else
	echo "nvim not installed."
end

if type -q starship
	starship init fish | source
else
	echo "Starship not installed."
end
