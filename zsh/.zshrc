# ~/.config/zsh/.zshrc — loaded because ~/.zshenv sets ZDOTDIR here.
# Layout mirrors dot_config/fish: this file is the zsh equivalent of
# fish's config.fish + functions/*.fish + conf.d/*.fish combined.

# --- distro base (was ~/.zshrc, stock Manjaro default) ---
USE_POWERLINE="true"
HAS_WIDECHARS="false"
if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
  source /usr/share/zsh/manjaro-zsh-config
fi
# manjaro-zsh-prompt (powerlevel10k) is intentionally NOT sourced here —
# it would override the oh-my-zsh theme set below, since it re-asserts
# its own prompt on every precmd. oh-my-zsh's ZSH_THEME is the prompt now.

# --- aliases (from fish functions/*.fish) ---
alias c='clear'
alias e='exa --icons'
alias elah='exa -lah'
alias ff='fastfetch'
alias g='git'
alias gb='git branch'
alias gco='git checkout'          # was tangled up with `gb` in the fish version
alias gc='git add . && git commit -m'
alias gdf='git diff'
alias glog='git log'
alias gp='git push origin'
alias gpl='git pull origin'
alias gs='git status'
alias r='rm -rf'
alias t='tree'
alias v='nvim'
# no separate `z` alias needed — zoxide's own init below provides the `z` command

# --- tmux sessionizer (fish's tmux_sessionizer.fish + config.fish binds) ---
tmux-sessionizer() {
  local selected
  if [[ $# -eq 1 ]]; then
    selected="$1"
  else
    selected=$(find ~/work ~/learn ~/build ~/projects -mindepth 1 -maxdepth 1 -type d 2>/dev/null | fzf)
  fi
  [[ -z "$selected" ]] && return 0

  local selected_name=$(basename "$selected" | tr . _)
  local tmux_running=$(pgrep tmux)

  if [[ -z "$TMUX" && -z "$tmux_running" ]]; then
    tmux new-session -s "$selected_name" -c "$selected"
    return 0
  fi

  if ! tmux has-session -t "$selected_name" 2>/dev/null; then
    tmux new-session -ds "$selected_name" -c "$selected"
  fi
  tmux switch-client -t "$selected_name"
}

tmux-attach-session() {
  tmux ls
  echo -n 'Attach session: '
  read session
  tmux attach -t "$session"
}

# fish's `bind \cf ...` -> zsh: bind the key to type+enter the command
bindkey -s '^f' 'tmux-sessionizer\n'
bindkey -s '^a' 'tmux-attach-session\n'
bindkey -s '^l' 'tmux ls\n'
bindkey -s '^q' 'tmux detach\n'

# --- zoxide (was: `zoxide init fish | source`) ---
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

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

# --- nvm (fish_plugins had jorgebucaran/nvm.fish, default version was 24) ---
# export NVM_DIR="$HOME/.nvm"
# [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
# nvm alias default 24 >/dev/null 2>&1

# --- misc (was in fish_variables) ---
export VIRTUAL_ENV_DISABLE_PROMPT=true

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="dstufft"
plugins=(git)

source $ZSH/oh-my-zsh.sh
source <(fzf --zsh)


# pnpm
export PNPM_HOME="/home/f/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
