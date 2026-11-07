#!/usr/bin/env bash
# Starts Vivado from build/vivado so its log files stay out of the source
# folders. Set VIVADO_ROOT if Vivado is not in /opt/Xilinx/2026.1/Vivado.
set -eo pipefail

caller_dir="$PWD"
project_root="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
    pwd -P
)"
vivado_root="${VIVADO_ROOT:-/opt/Xilinx/2026.1/Vivado}"

if [[ ! -x "$vivado_root/bin/vivado" ]]; then
    printf 'Vivado not found at %s/bin/vivado. Set VIVADO_ROOT to its installation directory.\n' "$vivado_root" >&2
    exit 127
fi

# Make -source and .xpr paths absolute; leave -tclargs as is.
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[i]}" in
        -tclargs) break ;;
        -source)
            if ((i + 1 >= ${#args[@]})); then
                printf '%s\n' '-source requires a Tcl file path.' >&2
                exit 2
            fi
            i=$((i + 1))
            if [[ "${args[i]}" != /* ]]; then
                args[i]="$caller_dir/${args[i]}"
            fi
            ;;
        *.xpr)
            if [[ "${args[i]}" != /* ]]; then
                args[i]="$caller_dir/${args[i]}"
            fi
            ;;
    esac
done

source "$vivado_root/settings64.sh"
mkdir -p -- "$project_root/build/vivado"
cd -- "$project_root/build/vivado"
exec "$vivado_root/bin/vivado" "${args[@]}"
