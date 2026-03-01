# tilde

macOS dotfiles. Clones into `$HOME` and manages shell config, app
preferences, Homebrew packages, Setapp apps, and LaunchAgents.

## Install

```sh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/maximlevey/tilde/main/bootstrap.sh)"
```

## Structure

Each `.<app>/` directory contains a `bootstrap.sh` and a `preferences.json`.
Bootstrap scripts handle setup (symlinks, quit/restart) and delegate
preference writing to `setprefs`, which applies typed JSON via `defaults write`.
