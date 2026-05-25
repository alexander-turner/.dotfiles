function claude --wraps claude --description 'Claude Code with AI secrets from envchain'
    envchain ai $DOTFILES_DIR/secure-claude-code-defaults/bin/claude $argv
end
