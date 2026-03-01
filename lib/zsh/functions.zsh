#
# Interactive shell utility functions.

# Install a Homebrew cask.
cask() {
  /opt/homebrew/bin/brew "$@" --cask
}

# Commit all changes with today's date and push.
commit() {
  /usr/bin/git commit -a -m "$(date +%F)" && /usr/bin/git push
}

# Open a file in LightEdit.
edit() {
  [[ -e "$1" ]] && /usr/bin/open -b "com.maximlevey.LightEdit" "$1"
}

# Jump to a project directory under $SRC by name.
repo() {
  jump "$(find "${SRC}" -maxdepth 2 -name "*$1" -type d -print -quit)"
}

# Copy the machine serial number to the clipboard.
serial() {
  pcp "$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')"
}

# Copy the public IP address to the clipboard.
ip() {
  pcp "$(curl -s -4 icanhazip.com)"
}

# Open .zshrc for editing.
zshrc() {
  jump "${HOME}/.zshrc"
}
