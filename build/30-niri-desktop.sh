#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Niri Desktop Installation
###############################################################################
# This script installs the Niri scrollable-tiling Wayland compositor alongside
# the existing GNOME desktop. Users can choose between GNOME and Niri at login.
#
# Niri is a modern Wayland compositor with a unique scrollable tiling layout.
# https://github.com/YaLTeR/niri
#
# Niri is available in Fedora repositories for Fedora 41+ and also via COPR
# for newer development versions.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

echo "::group:: Install Niri Compositor"

# Install niri from Fedora repositories (available in Fedora 41+)
# For development/git versions, use: copr_install_isolated "yalter/niri-git" niri
# dnf5 install -y niri

copr_install_isolated "avengemedia/dms" \
	niri \
	dms \

echo "Niri compositor installed successfully"
echo "::endgroup::"

echo "::group:: Install Essential Utilities"

# Install essential utilities for Wayland desktop experience
dnf5 install -y \
    alacritty \
    fuzzel \
    swaybg \
    swayidle \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome \
    polkit \
    pipewire \
    wireplumber \
    xwayland-satellite \
    udiskie

echo "Essential utilities installed"
echo "::endgroup::"

echo "::group:: Configure GDM Session"

# Create Wayland session entry for GDM
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/niri.desktop << 'NIRIDESKTOP'
[Desktop Entry]
Name=Niri
Comment=A scrollable-tiling Wayland compositor
Exec=niri-session
Type=Application
DesktopNames=niri
NIRIDESKTOP

echo "::endgroup::"

echo "::group:: Configure Niri"

# Enable niri.service for user sessions by creating symlinks
# Cannot use systemctl during container build, so we create symlinks manually
mkdir -p /usr/lib/systemd/user/default.target.wants
ln -sf /usr/lib/systemd/user/niri.service /usr/lib/systemd/user/default.target.wants/niri.service

# Enable dms (display manager service) for niri
if [ -f /usr/lib/systemd/user/dms.service ]; then
    ln -sf /usr/lib/systemd/user/dms.service /usr/lib/systemd/user/default.target.wants/dms.service
fi

# Create default config directory
mkdir -p /etc/skel/.config/niri

# Create a basic default configuration
cat > /etc/skel/.config/niri/config.kdl << 'NIRICONFIG'
// Niri default configuration for atmxos
// See https://github.com/YaLTeR/niri/wiki/Configuration:-Overview

input {
    keyboard {
        xkb {
            layout "us"
        }
    }
    
    touchpad {
        tap
        natural-scroll
    }
}

output {
    scale 1.0
}

layout {
    gaps 8
    
    focus-ring {
        width 2
        active-color "#7fc8ff"
        inactive-color "#505050"
    }
}

// Default keybindings
binds {
    Mod+Return { spawn "alacritty"; }
    Mod+D { spawn "fuzzel"; }
    Mod+Q { close-window; }
    
    // Window management
    Mod+Left { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Up { focus-window-up; }
    Mod+Down { focus-window-down; }
    
    Mod+Shift+Left { move-column-left; }
    Mod+Shift+Right { move-column-right; }
    Mod+Shift+Up { move-window-up; }
    Mod+Shift+Down { move-window-down; }
    
    // Workspace management
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    
    Mod+Shift+1 { move-window-to-workspace 1; }
    Mod+Shift+2 { move-window-to-workspace 2; }
    Mod+Shift+3 { move-window-to-workspace 3; }
    Mod+Shift+4 { move-window-to-workspace 4; }
    Mod+Shift+5 { move-window-to-workspace 5; }
    
    // System
    Mod+Shift+E { quit; }
    Mod+Shift+Q { power-off-monitors; }
}

// Window rules
window-rules {
    // Add custom window rules here
}

spawn-at-startup "swaybg" "-c" "#1a1a1a"

prefer-no-csd
NIRICONFIG

echo "Niri configuration created"
echo "::endgroup::"

echo "Niri desktop installation complete!"
echo "Both GNOME and Niri are now available as desktop options."
echo "After booting, select your preferred session at the GDM login screen:"
echo "  - 'GNOME' for the traditional GNOME desktop"
echo "  - 'Niri' for the scrollable-tiling compositor"
echo ""
echo "Niri default keybindings:"
echo "  - Mod+Return: Open terminal (alacritty)"
echo "  - Mod+D: Application launcher (fuzzel)"
echo "  - Mod+Q: Close window"
echo "  - Mod+Shift+E: Exit Niri"
