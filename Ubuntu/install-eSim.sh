#!/bin/bash
#=============================================================================
#          FILE: install-eSim.sh
#
#         USAGE: ./install-eSim.sh --install
#                            OR
#                ./install-eSim.sh --uninstall
#
#   DESCRIPTION: Version dispatcher for the eSim EDA Suite installer.
#                Selects the OS-specific script from install-eSim-scripts/.
#
#       OPTIONS: --
#  REQUIREMENTS: --
#          BUGS: --
#         NOTES: --
#       AUTHORS: Fahim Khan, Rahul Paknikar, Saurabh Bansode,
#                Sumanto Kar, Partha Singha Roy, Jayanth Tatineni,
#                Anshul Verma, Shiva Krishna Sangati, Harsha Narayana P
#  ORGANIZATION: eSim Team, FOSSEE, IIT Bombay
#       CREATED: Wednesday 15 July 2015 15:26
#      REVISION: Sunday 22 November 2026 (Task 4 fixes)
#=============================================================================

# -----------------------------------------------------------------------------
# FIX 1 (syntax): the upstream installers-branch copy of this file had a block
# of config-writing echo lines (and a whole second copy of the version-script
# functions) pasted inside run_version_script().  The `if [[ -f "$SCRIPT" ]]`
# was never closed with `fi`, so `bash -n` failed with:
#   line 70: syntax error near unexpected token `}'
# and the installer could not start at all.  Those stray lines/functions were
# dead code and have been removed; this file is now a dispatcher only.
#
# FIX 2 (Ubuntu 25.04 detection): `lsb_release -d` prints "Ubuntu 25.04", which
# has only two numeric components, so `grep -oP '\d+\.\d+\.\d+'` returned an
# empty string.  Use `lsb_release -rs` (with an /etc/os-release fallback).
# -----------------------------------------------------------------------------

get_ubuntu_version() {
    VERSION_ID=$(. /etc/os-release && printf '%s' "$VERSION_ID")
    if ! FULL_VERSION=$(lsb_release -rs 2>/dev/null); then
        FULL_VERSION="$VERSION_ID"
    fi
    echo "Detected Ubuntu Version: $VERSION_ID ($FULL_VERSION)"
}

run_version_script() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-eSim-scripts"

    case "$VERSION_ID" in
        "22.04")
            if [[ "$FULL_VERSION" == "22.04.4" ]]; then
                SCRIPT="$SCRIPT_DIR/install-eSim-22.04.sh"
            else
                SCRIPT="$SCRIPT_DIR/install-eSim-23.04.sh"
            fi
            ;;
        "23.04")
            SCRIPT="$SCRIPT_DIR/install-eSim-23.04.sh"
            ;;
        "24.04")
            SCRIPT="$SCRIPT_DIR/install-eSim-24.04.sh"
            ;;
        "25.04")
            SCRIPT="$SCRIPT_DIR/install-eSim-25.04.sh"
            ;;
        *)
            echo "Unsupported Ubuntu version: $VERSION_ID ($FULL_VERSION)"
            exit 1
            ;;
    esac

    if [[ ! -f "$SCRIPT" ]]; then
        echo "Installation script not found: $SCRIPT"
        exit 1
    fi

    echo "Running script: $SCRIPT $ARGUMENT"
    bash "$SCRIPT" "$ARGUMENT"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if [[ $# -ne 1 ]]; then
    echo "USAGE : "
    echo "./install-eSim.sh --install"
    echo "./install-eSim.sh --uninstall"
    exit 1
fi

ARGUMENT=$1
if [[ "$ARGUMENT" != "--install" && "$ARGUMENT" != "--uninstall" ]]; then
    echo "Invalid argument: $ARGUMENT"
    echo "Usage: $0 --install | --uninstall"
    exit 1
fi

get_ubuntu_version
run_version_script
