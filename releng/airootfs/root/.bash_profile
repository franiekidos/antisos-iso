# /root/.bash_profile
MARKER="/tmp/antisos-wizard-ran"

if [ ! -f "$MARKER" ]; then
    touch "$MARKER"
    sh pre-desktop-wizard
fi