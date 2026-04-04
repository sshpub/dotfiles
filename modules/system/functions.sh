#!/usr/bin/env bash

dotfiles_section "system.info" && {
    sysinfo() {
        echo "System Information:"
        if is_macos; then
            echo "  OS: macOS $(sw_vers -productVersion)"
            echo "  CPU: $(sysctl -n machdep.cpu.brand_string)"
            echo "  Memory: $(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 )) GB"
        elif is_linux; then
            echo "  OS: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
            echo "  CPU: $(lscpu 2>/dev/null | grep 'Model name' | cut -d: -f2 | xargs)"
            echo "  Memory: $(free -h 2>/dev/null | awk '/^Mem:/{print $2}')"
        fi
        echo "  Kernel: $(uname -r)"
        echo "  Arch: $(uname -m)"
        echo "  Uptime: $(uptime -p 2>/dev/null || uptime)"
    }

    # Quick calculator
    calc() { echo "$*" | bc -l; }
}
