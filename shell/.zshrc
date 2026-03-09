# ~/.zshrc
# Main zsh configuration file

# =============================================================================
# OH-MY-ZSH CONFIGURATION
# =============================================================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
  git
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  golang
  minikube
  kubectl
  poetry
  pyenv
)

source $ZSH/oh-my-zsh.sh

# =============================================================================
# SHELL OPTIONS & COMPLETIONS
# =============================================================================

# Initialize completions
autoload -Uz compinit && compinit

# Custom completions directory
fpath=($HOME/.zsh_completions $fpath)

# =============================================================================
# EDITOR PREFERENCES
# =============================================================================

export EDITOR='nvim'
export VISUAL='nvim'

# =============================================================================
# PROGRAMMING LANGUAGES & RUNTIMES
# =============================================================================

# Java
export JAVA_HOME=/opt/homebrew/opt/openjdk/

# Go
export GOPATH=$(go env GOPATH)
export GOROOT=$(go env GOROOT)
export GOBIN=$(go env GOBIN)
export GOARCH=arm64

# Python (Pyenv)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# Poetry
export POETRY_HOME=$HOME/.local/bin
export PATH="$HOME/.poetry/bin:$PATH"

# =============================================================================
# DEVELOPMENT TOOLS & SERVICES
# =============================================================================

# Docker
export DOCKER_VOLUMES="$HOME/docker-volumes"

# Kafka
if [ -d "$HOME/kafka" ]; then
  export KAFKA_HOME="$HOME/kafka"
  export PATH="$PATH:$KAFKA_HOME/bin"
fi

# Local BigTable Emulator
export LOCAL_BIGTABLE_HOST=localhost:8086
export LOCAL_BIGTABLE_EMULATOR_HOST=localhost:8086

# =============================================================================
# AI TOOLS
# =============================================================================

# Ollama
export OLLAMA_HOST="127.0.0.1:5000"

# =============================================================================
# PATH CONFIGURATION
# =============================================================================

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Consolidated system PATH
export PATH="/usr/local/bin/:$HOME/.local/bin/bin/:/usr/local/opt/libpq/bin:/opt/homebrew/bin:$JAVA_HOME:/usr/local/bin:$POETRY_HOME:$KAFKA_HOME/bin:$GOPATH/bin:$GOROOT/bin:$PATH"

# =============================================================================
# SHELL COMPLETIONS & INTEGRATIONS
# =============================================================================

# Kubectx
source $(brew --prefix)/etc/bash_completion.d/kubectx

# Google Cloud SDK
if [ -f "$HOME/bigdata/google-cloud-sdk/path.zsh.inc" ]; then
  source "$HOME/bigdata/google-cloud-sdk/path.zsh.inc"
fi

if [ -f "$HOME/bigdata/google-cloud-sdk/completion.zsh.inc" ]; then
  source "$HOME/bigdata/google-cloud-sdk/completion.zsh.inc"
fi

# =============================================================================
# EXTERNAL CONFIGURATION FILES
# =============================================================================

# Aliases
if [ -f ~/dotfiles/shell/aliases ]; then
  source ~/dotfiles/shell/aliases
fi

# Tool-specific configs
source ~/.db_config
