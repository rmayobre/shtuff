#!/usr/bin/env bash

# Function: install_steamcmd
# Description: Detects the system's package manager and installs SteamCMD
#              along with required dependencies (lib32gcc1, lib32stdc++6, etc.)
# Globals: None
# Arguments: None
# Outputs: Status messages to stdout, errors to stderr.
# Returns: 0 on successful installation, 1 if package manager unknown or installation fails.
install_steamcmd() {
    echo "=== Installing SteamCMD ==="

    if command -v apt &> /dev/null; then
        install_steamcmd_apt
    elif command -v dnf &> /dev/null; then
        install_steamcmd_dnf
    elif command -v yum &> /dev/null; then
        install_steamcmd_yum
    elif command -v zypper &> /dev/null; then
        install_steamcmd_zypper
    elif command -v pacman &> /dev/null; then
        install_steamcmd_pacman
    elif command -v apk &> /dev/null; then
        install_steamcmd_apk
    else
        echo "Error: Could not determine the primary package manager."
        echo "Cannot proceed with SteamCMD installation."
        return 1
    fi
}

# Function to install SteamCMD using APT (Ubuntu/Debian)
install_steamcmd_apt() {
    echo "--- Installing SteamCMD with APT ---"

    # Enable multiverse repository for Ubuntu
    if lsb_release -si 2>/dev/null | grep -qi ubuntu; then
        echo "Enabling multiverse repository for Ubuntu..."
        sudo add-apt-repository multiverse -y
    fi

    # Update package list
    sudo apt update

    # Accept Steam license automatically
    echo "steam steam/question select I AGREE" | sudo debconf-set-selections
    echo "steam steam/license note ''" | sudo debconf-set-selections

    # Install required 32-bit libraries and SteamCMD
    echo "Installing 32-bit libraries and SteamCMD..."
    sudo dpkg --add-architecture i386
    sudo apt update
    sudo apt install -y lib32gcc-s1 lib32stdc++6 steamcmd

    # Create symlink for easier access
    if [ ! -L /usr/local/bin/steamcmd ]; then
        sudo ln -sf /usr/games/steamcmd /usr/local/bin/steamcmd
    fi

    echo "SteamCMD installed successfully via APT!"
    echo "You can run it with: steamcmd"
}

# Function to install SteamCMD using DNF (Fedora/RHEL 8+)
install_steamcmd_dnf() {
    echo "--- Installing SteamCMD with DNF ---"

    # Enable RPM Fusion repositories
    echo "Enabling RPM Fusion repositories..."
    sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    # Install required dependencies
    echo "Installing required dependencies..."
    sudo dnf install -y glibc.i686 libstdc++.i686 wget curl tar

    # Download and install SteamCMD manually
    install_steamcmd_manual

    echo "SteamCMD installed successfully via DNF!"
}

# Function to install SteamCMD using YUM (CentOS/RHEL 7)
install_steamcmd_yum() {
    echo "--- Installing SteamCMD with YUM ---"

    # Install EPEL repository
    echo "Installing EPEL repository..."
    sudo yum install -y epel-release

    # Install required dependencies
    echo "Installing required dependencies..."
    sudo yum install -y glibc.i686 libstdc++.i686 wget curl tar

    # Download and install SteamCMD manually
    install_steamcmd_manual

    echo "SteamCMD installed successfully via YUM!"
}

# Function to install SteamCMD using Zypper (openSUSE)
install_steamcmd_zypper() {
    echo "--- Installing SteamCMD with Zypper ---"

    # Install required dependencies
    echo "Installing required dependencies..."
    sudo zypper --non-interactive install glibc-32bit libstdc++6-32bit wget curl tar

    # Download and install SteamCMD manually
    install_steamcmd_manual

    echo "SteamCMD installed successfully via Zypper!"
}

# Function to install SteamCMD using Pacman (Arch Linux)
install_steamcmd_pacman() {
    echo "--- Installing SteamCMD with Pacman ---"

    # Enable multilib repository
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo "Enabling multilib repository..."
        sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
        sudo pacman -Sy
    fi

    # Install SteamCMD from AUR (if available) or manually
    if command -v yay &> /dev/null; then
        echo "Installing SteamCMD via yay (AUR helper)..."
        yay -S --noconfirm steamcmd
    elif command -v paru &> /dev/null; then
        echo "Installing SteamCMD via paru (AUR helper)..."
        paru -S --noconfirm steamcmd
    else
        echo "Installing required dependencies..."
        sudo pacman -S --noconfirm lib32-gcc-libs wget curl tar
        install_steamcmd_manual
    fi

    echo "SteamCMD installed successfully via Pacman!"
}

# Function to install SteamCMD using APK (Alpine Linux)
install_steamcmd_apk() {
    echo "--- Installing SteamCMD with APK ---"

    echo "Note: SteamCMD support on Alpine Linux is limited due to glibc requirements."
    echo "Installing gcompat for glibc compatibility..."

    # Install required dependencies
    sudo apk add gcompat wget curl tar

    # Download and install SteamCMD manually
    install_steamcmd_manual

    echo "SteamCMD installed on Alpine Linux (experimental support)!"
    echo "Note: Some Steam games may not work properly on Alpine Linux."
}

# Function to manually install SteamCMD (for distributions without native packages)
install_steamcmd_manual() {
    echo "Installing SteamCMD manually..."

    # Create steamcmd user if it doesn't exist
    if ! id -u steamcmd &>/dev/null; then
        echo "Creating steamcmd user..."
        sudo useradd -r -m -d /opt/steamcmd -s /bin/bash steamcmd
    fi

    # Create installation directory
    sudo mkdir -p /opt/steamcmd

    # Download SteamCMD
    echo "Downloading SteamCMD..."
    cd /tmp
    wget -O steamcmd_linux.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz

    # Extract to installation directory
    echo "Extracting SteamCMD..."
    sudo tar -xzf steamcmd_linux.tar.gz -C /opt/steamcmd/
    sudo chown -R steamcmd:steamcmd /opt/steamcmd/
    sudo chmod +x /opt/steamcmd/steamcmd.sh

    # Create wrapper script
    sudo tee /usr/local/bin/steamcmd > /dev/null << 'EOF'
#!/bin/bash
cd /opt/steamcmd
exec ./steamcmd.sh "$@"
EOF

    sudo chmod +x /usr/local/bin/steamcmd

    # Clean up
    rm -f /tmp/steamcmd_linux.tar.gz

    echo "Manual SteamCMD installation completed!"
}

# Function to verify SteamCMD installation
verify_steamcmd() {
    echo "=== Verifying SteamCMD Installation ==="

    if command -v steamcmd &> /dev/null; then
        echo "✓ SteamCMD is available in PATH"
        echo "Testing SteamCMD..."

        # Test SteamCMD with a simple command
        timeout 10s steamcmd +quit 2>/dev/null
        if [ $? -eq 0 ] || [ $? -eq 124 ]; then
            echo "✓ SteamCMD appears to be working correctly"
            echo ""
            echo "Usage examples:"
            echo "  steamcmd +help +quit"
            echo "  steamcmd +login anonymous +app_update 740 +quit"
            echo ""
            echo "Note: First run will download additional updates."
        else
            echo "⚠ SteamCMD may have issues. Try running 'steamcmd +quit' manually."
        fi
    else
        echo "✗ SteamCMD not found in PATH"
        echo "Installation may have failed or requires a shell restart."
        return 1
    fi
}

# Function to show usage information
show_usage() {
    echo "SteamCMD Installation Script"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  install    Install SteamCMD"
    echo "  verify     Verify SteamCMD installation"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 install    # Install SteamCMD"
    echo "  $0 verify     # Verify installation"
}

# Main script execution
main() {
    case "${1:-install}" in
        install)
            install_steamcmd
            echo ""
            verify_steamcmd
            ;;
        verify)
            verify_steamcmd
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
