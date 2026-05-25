function claude --wraps claude --description 'Claude Code with AI secrets from envchain'
    set -lx ANTHROPIC_API_KEY (envchain ai printenv ANTHROPIC_API_KEY)
    set -lx VENICE_INFERENCE_KEY (envchain ai printenv VENICE_INFERENCE_KEY)
    $DOTFILES_DIR/secure-claude-code-defaults/bin/claude $argv
end
