# ~/.config/zsh/.zshrc — loaded because ~/.zshenv sets ZDOTDIR here.
# Layout mirrors dot_config/fish: this file is the zsh equivalent of
# fish's config.fish + functions/*.fish + conf.d/*.fish combined.

# --- distro base (was ~/.zshrc, stock Manjaro default) ---
USE_POWERLINE="true"
HAS_WIDECHARS="false"
if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
  source /usr/share/zsh/manjaro-zsh-config
fi

alias c='clear'
alias e='exa --icons'
alias elah='exa -lah'
alias ff='fastfetch'
alias g='git'
alias gb='git branch'
alias gco='git checkout'          
alias gc='git add . && git commit -m'
alias gdf='git diff'
alias glog='git log'
alias gp='git push origin'
alias gpl='git pull origin'
alias gs='git status'
alias r='rm -rf'
alias t='tree'
alias v='nvim'

# tmux-sessionizer is a script on PATH (zsh/tmux-sessioniser.sh, linked to
# ~/.local/bin/tmux-sessionizer). It used to be a function here; a function of
# the same name would shadow the script, so it was removed rather than renamed.
# Search paths live in zsh/tmux-sessionizer.conf.

tmux-attach-session() {
  tmux ls
  echo -n 'Attach session: '
  read session
  tmux attach -t "$session"
}

bindkey -s '^f' 'tmux-sessionizer\n'
bindkey -s '^a' 'tmux-attach-session\n'
bindkey -s '^l' 'tmux ls\n'
bindkey -s '^q' 'tmux detach\n'

command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# --- pnpm ---
export PNPM_HOME="/home/f/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# --- opencode ---
export PATH="$HOME/.opencode/bin:$PATH"

# --- deno (was conf.d/deno.fish) ---
[[ -f "$HOME/.deno/env" ]] && source "$HOME/.deno/env"

# --- rustup/cargo (was conf.d/rustup.fish) ---
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# --- misc (was in fish_variables) ---
export VIRTUAL_ENV_DISABLE_PROMPT=true

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="dstufft"
plugins=(git)

source $ZSH/oh-my-zsh.sh

# --- fzf -------------------------------------------------------------------
# Appearance lives in fzf/fzfrc so it can carry comments; only behaviour and
# the per-keybinding previews are set here.
export FZF_DEFAULT_OPTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzfrc"

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# eza and fd colour their own output through the terminal's 16 ANSI slots,
# which ghostty maps to the Xcode palette -- so previews match without either
# tool needing a theme of its own.
export FZF_CTRL_T_OPTS="
  --prompt='   '
  --preview='[ -d {} ] && eza --tree --level=2 --color=always {} || head -200 {}'
  --preview-window=right,55%,border-left
"

export FZF_ALT_C_OPTS="
  --prompt='   '
  --preview='eza --tree --level=2 --color=always {}'
  --preview-window=right,55%,border-left
"

export FZF_CTRL_R_OPTS="
  --prompt='   '
  --preview='echo {}'
  --preview-window=down,3,wrap,border-top
"

source <(fzf --zsh)


# pnpm
export PNPM_HOME="/home/f/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
