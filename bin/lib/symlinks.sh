# shellcheck shell=bash
# bin/lib/symlinks.sh — shared list of managed dotfile symlinks.
#
# Each emitted line is `target|source|label`, pipe-delimited. Callers iterate
# with `while IFS='|' read -r target source label; do …; done < <(managed_symlinks)`.
# DOTFILES_DIR must be set in the caller before invoking.
#
# Maintenance invariant: every safe_link in setup.bash whose target lives in
# $HOME should have a matching entry here (or be intentionally bespoke).
# Anything bespoke — the in-repo .hooks/pre-push relative symlink, the ccr
# launch agent, etc. — stays inline in setup.bash / doctor.bash / uninstall.bash.
managed_symlinks() {
    cat <<EOF
$HOME/.bashrc|$DOTFILES_DIR/.bashrc|.bashrc
$HOME/.vimrc|$DOTFILES_DIR/.vimrc|.vimrc
$HOME/.gitconfig|$DOTFILES_DIR/.gitconfig|.gitconfig
$HOME/.tmux.conf|$DOTFILES_DIR/.tmux.conf|.tmux.conf
$HOME/.npmrc|$DOTFILES_DIR/.npmrc|.npmrc
$HOME/.pnpmrc|$DOTFILES_DIR/.pnpmrc|.pnpmrc
$HOME/.config/fish/config.fish|$DOTFILES_DIR/apps/fish/config.fish|fish config
$HOME/.config/fish/completions/dotfiles.fish|$DOTFILES_DIR/apps/fish/completions/dotfiles.fish|dotfiles fish completion
$HOME/.config/fish/conf.d/carapace.fish|$DOTFILES_DIR/apps/fish/conf.d/carapace.fish|carapace conf.d snippet
$HOME/.config/fish/conf.d/mise.fish|$DOTFILES_DIR/apps/fish/conf.d/mise.fish|mise conf.d snippet
$HOME/.local/bin/dotfiles|$DOTFILES_DIR/bin/dotfiles|dotfiles dispatcher
$HOME/.config/mods/mods.yml|$DOTFILES_DIR/apps/mods/mods.yml|mods config
$HOME/.ssh/config|$DOTFILES_DIR/apps/ssh/config|ssh config
$HOME/.config/mise/config.toml|$DOTFILES_DIR/apps/mise/config.toml|mise config
$HOME/.config/nvim|$DOTFILES_DIR/apps/nvim|nvim config
$HOME/.config/vagrant-templates/Vagrantfile|$DOTFILES_DIR/ai/Vagrantfile|vagrant-templates/Vagrantfile
$HOME/.local/bin/bw-node|$DOTFILES_DIR/bin/bw-node|bw-node wrapper
$HOME/.claude/settings.json|$DOTFILES_DIR/ai/prompting/settings.json|Claude Code settings
$HOME/.claude/CLAUDE.md|$DOTFILES_DIR/ai/prompting/CLAUDE.md|Claude Code global CLAUDE.md
$HOME/.claude/commands|$DOTFILES_DIR/ai/prompting/skills|Claude Code slash-command dir
$HOME/.local/bin/claude|$DOTFILES_DIR/bin/claude|claude shim
$HOME/.local/bin/claude-private|$DOTFILES_DIR/bin/claude-private|claude-private (ccr→Venice default_code, --think → Opus)
$HOME/.local/bin/claude-paranoid|$DOTFILES_DIR/bin/claude-paranoid|claude-paranoid (ccr→Venice default_code, always)
$HOME/.devcontainer|$DOTFILES_DIR/.devcontainer|.devcontainer
EOF
    if [[ "$(uname)" == "Darwin" ]]; then
        cat <<EOF
$HOME/.aerospace.toml|$DOTFILES_DIR/.aerospace.toml|.aerospace.toml
$HOME/Library/com.googlecode.iterm2.plist|$DOTFILES_DIR/apps/com.googlecode.iterm2.plist|iTerm2 plist
$HOME/.config/borders/bordersrc|$DOTFILES_DIR/apps/borders/bordersrc|borders config
$HOME/.config/swiftbar/vpn.10s.bash|$DOTFILES_DIR/apps/swiftbar/vpn.10s.bash|swiftbar vpn plugin
$HOME/Library/Application Support/VSCodium/User/settings.json|$DOTFILES_DIR/apps/vscodium/settings.json|VSCodium settings (macOS)
$HOME/Library/Application Support/VSCodium/User/keybindings.json|$DOTFILES_DIR/apps/vscodium/keybindings.json|VSCodium keybindings (macOS)
EOF
    else
        cat <<EOF
$HOME/.config/VSCodium/User/settings.json|$DOTFILES_DIR/apps/vscodium/settings.json|VSCodium settings (Linux)
$HOME/.config/VSCodium/User/keybindings.json|$DOTFILES_DIR/apps/vscodium/keybindings.json|VSCodium keybindings (Linux)
EOF
    fi
    for aider_file in "$DOTFILES_DIR"/.aider*; do
        [[ -f "$aider_file" ]] || continue
        local name
        name="$(basename "$aider_file")"
        printf '%s|%s|%s\n' "$HOME/$name" "$aider_file" "$name"
    done
}
