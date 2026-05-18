# shellcheck shell=bash
# bin/lib/symlinks.sh — shared list of managed dotfile symlinks.
#
# Each emitted line is `target|source|label`, pipe-delimited. Callers iterate
# with `while IFS='|' read -r target source label; do …; done < <(managed_symlinks)`.
# DOTFILES_DIR must be set in the caller before invoking.
#
# Maintenance invariant: every safe_link in setup.sh whose target lives in
# $HOME should have a matching entry here (or be intentionally bespoke).
# Anything bespoke — the in-repo .hooks/pre-push relative symlink, the ccr
# launch agent, etc. — stays inline in setup.sh / doctor.sh / uninstall.sh.
managed_symlinks() {
    cat <<EOF
$HOME/.bashrc|$DOTFILES_DIR/.bashrc|.bashrc
$HOME/.vimrc|$DOTFILES_DIR/.vimrc|.vimrc
$HOME/.gitconfig|$DOTFILES_DIR/.gitconfig|.gitconfig
$HOME/.tmux.conf|$DOTFILES_DIR/.tmux.conf|.tmux.conf
$HOME/.npmrc|$DOTFILES_DIR/.npmrc|.npmrc
$HOME/.pnpmrc|$DOTFILES_DIR/.pnpmrc|.pnpmrc
$HOME/.config/fish/config.fish|$DOTFILES_DIR/apps/fish/config.fish|fish config
$HOME/.config/mods/mods.yml|$DOTFILES_DIR/apps/mods/mods.yml|mods config
$HOME/.config/nvim|$DOTFILES_DIR/apps/nvim|nvim config
$HOME/.config/vagrant-templates/Vagrantfile|$DOTFILES_DIR/ai/Vagrantfile|vagrant-templates/Vagrantfile
EOF
    if [[ "$(uname)" == "Darwin" ]]; then
        cat <<EOF
$HOME/.aerospace.toml|$DOTFILES_DIR/.aerospace.toml|.aerospace.toml
$HOME/Library/com.googlecode.iterm2.plist|$DOTFILES_DIR/apps/com.googlecode.iterm2.plist|iTerm2 plist
$HOME/.config/borders/bordersrc|$DOTFILES_DIR/apps/borders/bordersrc|borders config
EOF
    fi
    for aider_file in "$DOTFILES_DIR"/.aider*; do
        [[ -f "$aider_file" ]] || continue
        local name
        name="$(basename "$aider_file")"
        printf '%s|%s|%s\n' "$HOME/$name" "$aider_file" "$name"
    done
}
