# External Wrapper for nvm-zsh

This document explains the optional external-wrapper mode introduced to:
- Reduce shell startup times
- Limit environment pollution from nvm
- Allow more customization options (isolation, shims, etc...)

## Purpose

The common way to use `nvm` is by sourcing the `nvm.sh` file, and it registers
all of the required functions and variables in the interactive shell, thus we
end up with many `nvm_*` functions and `NVM_*` variables that we as users don't
need or don't want them in our shell.

The wrapper concept can be used to prevent this and also gives the user:

- Fast, minimal shell startup (only a small wrapper is sourced).
- Isolation of nvm state (wrapper controls which variables/functions are exported).
- Running `nvm.sh` in executable mode: it returns a shell fragment describing
environment changes instead of directly mutating the current shell session.

## How it works (protocol)

1. The wrapper enables wrapper-mode by exporting two variables before invoking nvm.sh:
  - __NVM_ZSH_USES_WRAPPER (true/false) — tells nvm.sh a wrapper is present.
  - __NVM_ZSH_INIT_WRAPPER (set) — tells nvm.sh to only generate the
  environment-update string.

2. When called in wrapper-mode, `nvm.sh` calls `_nvm_init_wrapper` which:
  - Handles `nvm` calls, environment-update strings and other special cases.
  - Emits a small, safe shell snippet to stdout that represents the
  environment updates (exports, local NEW_PATH/DEFAULT_PATH, and some unset lines).

3. The wrapper must capture `nvm.sh` output and apply it to the current
shell (commonly via eval). The wrapper controls when PATH and other variables
are actually modified.

## Values returned by nvm.sh

When `_nvm_init_wrapper` is executed it returns the following output:

- local `NEW_PATH`: contains the updates that `nvm.sh` makes to
the `$PATH` variable.
- local `DEFAULT_PATH`: contains the path string without any presence of
`nvm.sh` on it.
- export `NVM_BIN`: contains the full path to the current node version `/bin`
directory.
- export `NVM_INC`: contains the full include (Native-API) path to the current
node version.
- export `NVM_CD_FLAGS`: nvm stuff.
- export `NVM_RC_VERSION`: node version found in the `.nvmrc` file inside the
current directory.
- export `NODE_PATH`: nvm stuff.

To better simulate the default `nvm.sh` behavior, these two variables
are always if `nvm.sh` also unsets them:

- unset `NVM_RC_VERSION`
- unset `NODE_PATH`

Special commands handling:
- `deactivate` → Environment-update: `unset NVM_BIN NVM_INC`
- `unload`     → Environment-update: `unset NVM_BIN NVM_INC NVM_COLORS NVM_CD_FLAGS NVM_RC_VERSION`
- `set-colors` → Environment-update: `export NVM_COLORS='...'`

The wrapper should evaluate the returned snippet so the current shell receives
the environment updates.

## Minimal example wrapper (zsh / POSIX-compatible)

Place this file somewhere you source at shell startup (example: `~/.config/nvm/sample.sh`),
then source the wrapper instead of `nvm.sh`:

```sh
# Example wrapper: do not source nvm.sh directly; let the wrapper manage it.
# custom NVM_DIR
export NVM_DIR="${NVM_DIR:-$XDG_DATA_HOME/nvm}"

# The wrapper can also handle the installation of `nvm.sh` and self-updates.
nvm-update() {
  local NVM_ZSH_URL=""
  local NVM_WRAPPER_URL=""

  # Do update
  echo "Updating..."
}

nvm() {
  # enable nvm.sh wrapper mode
  export __NVM_ZSH_USES_WRAPPER=1
  export __NVM_ZSH_INIT_WRAPPER=1

  # Capture environment-updates emitted by nvm.sh
  local env_updates
  env_updates="$("$NVM_DIR/nvm.sh" "$@")" || return $?

  # Apply the returned shell fragment
  # Note: eval executes in the current shell; only eval trusted output
  eval "${env_updates}"

  # Handle which variable are updated
  unset NVM_COLORS

  # Handle how the path variable is managed
  export PATH="$NEW_PATH" # for normal behavior
  export PATH="$DEFAULT_PATH" # for custom behavior, this is also useful when working with shell shims.

  # Cleanup
  unset NEW_PATH DEFAULT_PATH
}

nvm # used for the setup step, which required for having a working node installation.
```

Notes:
- The wrapper may implement its own caching, lazy-loading, or path-management behavior.
- Always evaluate only trusted output (the wrapper is typically local and controlled by the user).

The `nvm.zsh` is an example of a more complete wrapper, it provides useful features like:
- Automatic installation and update of `nvm.sh` and self-updates.
- Isolation through environment variables (HOME, CACHE, etc...)
- Shim support (uses `shim-examples/node`)

## Usage patterns

- Minimal startup: source only the wrapper file in your shell init (e.g. `.zshrc`).
- Wrapper can choose to:
  - Eval returned fragment to modify PATH immediately.
  - Apply changes only when `nvm` is invoked.
  - Apply additional isolation by mapping NVM dirs (home/config/cache) before calling nvm.sh.
  - More..

>NOTE: Is recommended to execute the wrapper one in order to setup a working Node version.

## Backwards compatibility

- If no wrapper is installed (or the two variables are not exported), `nvm.sh` behaves
exactly as it would be in a normal installation (`source nvm.sh` is valid).
- Wrapper mode is opt-in and does not change existing workflows until a wrapper is used.

## Security and trust

- The wrapper has total control over the `nvm.sh` installation and execution
this means, the wrapper can also do bad things like preloading a custom library
with malicious code.

- Wrappers can also implement installation and updating features, this means that
in most cases you don't need to install `nvm.sh` by yourself, but this also means
that you must check from where the `nvm.sh` file is being downloaded from.

## Example troubleshooting

- If `nvm` seems to do nothing, check that the wrapper:
  - Exports both __NVM_ZSH_USES_WRAPPER and __NVM_ZSH_INIT_WRAPPER.
  - Calls the correct `nvm.sh` executable path ($NVM_DIR/nvm.sh).
  - Captures and evals the output from nvm.sh.

## Migration notes

- To migrate from `nvm-sh/nvm`:
  1. Remove the current `nvm` installation.
  2. Download and install a valid wrapper into your `.zshrc` file.
  3. If the wrapper has support for updating and installing `nvm.sh` you don't
  need to do anything else.
  4. If the wrapper don't support updating and installing, you must then need
  to download the `nvm.sh` file from this repository and store in the path the
  wrapper expects it to be, you can check the value of `NVM_DIR`.

> NOTE: Depending on the installation method, you must also give execution
> permissions to the `nvm.sh` file, e.g. `chmod +x nvm.sh`

## Shims

A wrapper can also implement shims, which gives another powerfull feature
to them.

Shims are small executabels whose job is to execute the right final executable
file, thus giving them an advantage on how `node` and other related progams are
executed.

You can check the example at `shim-examples` which provides a fast overview of
what shims are and what they can do.
