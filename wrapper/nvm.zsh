# Custom setup for nvm-zsh, this is useful for users
# who want a better isolation and fast start-up times.

NVM_DIR="${NVM_DIR:-$XDG_DATA_HOME/nvm}"
NVM_ZSH_DISABLE_ISOLATION=false
NVM_ZSH_MODIFY_PATH=false

__NVM_HOME_DIR="$HOME"
$NVM_DISABLE_ISOLATION && __NVM_HOME_DIR="$NVM_DIR/home"
__NVM_CONFIG_DIR="$__NVM_HOME_DIR/.cache"
__NVM_CACHE_DIR="$__NVM_HOME_DIR/.cache"

__NVM_ZSH_INIT_WRAPPER=false
__NVM_ZSH_USES_WRAPPER=true

# Update and ensure nvm.sh is installed
nvm-update() {
  local NVM_ZSH_UPDATE_URL="https://github.com/LnxFCA/nvm-zsh/raw/refs/heads/main/nvm.sh"
  local NVM_WRAPPER_URL="https://github.com/LnxFCA/nvm-zsh/raw/refs/heads/main/wrapper/nvm.zsh"
  local NVM_ZSH_INSTALL_PATH="$NVM_DIR/nvm.sh"

  [ ! -d "$NVM_DIR" ] && mkdir -p "$NVM_DIR"
  [ -f "$NVM_ZSH_INSTALL_PATH" ] && rm "$NVM_ZSH_INSTALL_PATH"

  # Download nvm.sh
  printf ":: Updating nvm.sh installation... "

  if curl -L --silent "$NVM_ZSH_UPDATE_URL" > "$NVM_ZSH_INSTALL_PATH"; then
    chmod +x "$NVM_ZSH_INSTALL_PATH"
    echo "Done"
  else
    echo ":: Error updating nvm.sh"
  fi

  # Download nvm.zsh
  printf ":: Updating nvim.zsh installation... "
  if curl -L --silent "$NVM_WRAPPER_URL" > "${0:a}"; then
    echo "Done"
  else
    printf "\n:: Error updating nvm.zsh"
  fi
}

[ ! -f "$NVM_DIR/nvm.sh" ] && nvm-update

nvm() {
  # Setup isolation
  local HOME="${NVM_HOME_DIR:-$__NVM_HOME_DIR}"
  local XDG_CONFIG_HOME="${NVM_CONFIG_HOME:-$HOME/.config}"
  local XDG_CACHE_HOME="${NVM_CACHE_HOME:-$HOME/.cache}"

  # Don't save custom paths
  if [ ! $NVM_ZSH_DISABLE_ISOLATION ]; then
  __NVM_HOME_DIR="$HOME"
  __NVM_CONFIG_DIR="$XDG_CONFIG_HOME"
  __NVM_CACHE_DIR="$XDG_CACHE_HOME"
  fi

  [ ! -a "$HOME" ] && mkdir -p "$HOME"
  [ ! -a "$XDG_CONFIG_HOME" ] && mkdir -p "$XDG_CONFIG_HOME"
  [ ! -a "$XDG_CACHE_HOME" ] && mkdir -p "$XDG_CACHE_HOME"

  # Prevent unwanted $PATH modification

  # Capture environment update
  env_capture="$(
    export __NVM_ZSH_INIT_WRAPPER \
           __NVM_ZSH_USES_WRAPPER \
           HOME \
           XDG_CONFIG_HOME \
           XDG_CACHE_HOME \
           NVM_DIR

    "$NVM_DIR/nvm.sh" "$@"
  )"

  eval "$env_capture"

  $NVM_ZSH_MODIFY_PATH && export PATH="$NEW_PATH"
  unset NEW_PATH DEFAULT_PATH
}

export NVM_DIR
export __NVM_HOME_DIR
export __NVM_CONFIG_DIR
export __NVM_CACHE_DIR

# Initial run
nvm

unset __NVM_INIT
