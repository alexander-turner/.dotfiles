#!/usr/bin/env fish

set -l OS (uname -s)

# Check for brew on macOS and install if missing
if test $OS = Darwin
    echo ":: Installing macOS apps..."
    # Tap necessary sources
    brew tap yakitrak/yakitrak >/dev/null
    brew tap rishikanthc/scriberr >/dev/null

    set -l GIT_ROOT (git rev-parse --show-toplevel 2>/dev/null)
    cd $GIT_ROOT
    cat ./apps/mac_brew.txt | xargs brew install --quiet
end

# Install autojump manually for both Linux and macOS
echo ":: Installing autojump..."
set -l AUTOJUMP_DIR /tmp/autojump
if test -d $AUTOJUMP_DIR
    rm -rf $AUTOJUMP_DIR
end

git clone --quiet https://github.com/wting/autojump.git $AUTOJUMP_DIR >/dev/null 2>&1
if test $status -ne 0
    echo "Error: Failed to clone autojump repository." >&2
    exit 3
end

cd $AUTOJUMP_DIR
python3 install.py >/dev/null 2>&1
set -l install_status $status

cd -
rm -rf $AUTOJUMP_DIR

if test $install_status -ne 0
    echo "Error: autojump installation failed." >&2
    exit 4
end

exit 0
