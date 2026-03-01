#
# Shell built-in wrappers and overrides.

# Open the current directory when called with no arguments.
open() {
  if [[ "$#" -eq 0 ]]; then
    /usr/bin/open "${PWD}"
  else
    /usr/bin/open "$@"
  fi
}
