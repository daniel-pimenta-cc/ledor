#!/bin/sh
# Registers Ledor with the desktop environment. Docks and app grids match
# the window's app_id (com.pimenta.ledor) against a desktop entry of the
# same name — without one the window gets a generic icon, especially on
# Wayland where gtk_window_set_icon() is ignored.
#
# Run it from the unpacked bundle directory (it is shipped at the bundle
# root next to the `ledor` binary). Re-run after moving the bundle.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS"
cat > "$APPS/com.pimenta.ledor.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ledor
Comment=Leitor RSVP de EPUB e artigos web
Exec=$DIR/ledor
Icon=$DIR/ledor.png
Terminal=false
Categories=Office;Viewer;Literature;
StartupWMClass=com.pimenta.ledor
EOF
update-desktop-database "$APPS" 2>/dev/null || true
echo "Desktop entry instalada em $APPS/com.pimenta.ledor.desktop"
