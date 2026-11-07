#!/bin/bash
set -euo pipefail

action="${1:?install or uninstall}"
destination="${INSTALL_DIR:-/Applications}"
app="${destination%/}/Kanta.app"

if [[ ! -d "$destination" || ! -w "$destination" ]]; then
    printf 'Kanta needs write access to %s. Use an administrator account or set INSTALL_DIR to a writable folder.\n' "$destination" >&2
    exit 1
fi
if [[ -L "$app" || ( -e "$app" && ! -d "$app" ) ]]; then
    printf 'Expected an application directory at %s.\n' "$app" >&2
    exit 1
fi

case "$action" in
    install)
        source_app="$(cd "$(dirname "$0")/.." && pwd)/dist/Kanta.app"
        if [[ ! -d "$source_app" ]]; then
            echo "Build Kanta.app before installing." >&2
            exit 1
        fi
        stage="$(mktemp -d "${destination%/}/.kanta-install.XXXXXX")"
        cleanup() {
            if [[ -d "$stage/previous.app" && ! -e "$app" ]]; then
                if ! mv "$stage/previous.app" "$app"; then
                    printf 'The previous application is saved at %s/previous.app.\n' "$stage" >&2
                    return
                fi
            fi
            rm -rf "$stage"
        }
        trap cleanup EXIT
        ditto "$source_app" "$stage/Kanta.app"
        codesign --verify --strict "$stage/Kanta.app"
        if [[ -d "$app" ]]; then mv "$app" "$stage/previous.app"; fi
        mv "$stage/Kanta.app" "$app"
        printf 'Installed %s\n' "$app"
        if [[ "${OPEN_AFTER_INSTALL:-1}" == 1 ]]; then open "$app"; fi
        ;;
    uninstall)
        if [[ -d "$app" ]]; then
            rm -r "$app"
            printf 'Removed %s\n' "$app"
        else
            printf 'No Kanta installation at %s\n' "$app"
        fi
        ;;
    *) echo "Usage: install.sh install|uninstall" >&2; exit 2 ;;
esac
