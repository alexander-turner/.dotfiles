function claude --wraps claude --description 'Claude Code with AI secrets from envchain'
    # Only override the inherited environment when envchain actually returns a
    # value. A failed lookup (locked keychain, unseeded 'ai' namespace) must not
    # clobber a working key already present in the environment with an empty one.
    set -l anthropic (envchain ai printenv ANTHROPIC_API_KEY 2>/dev/null)
    test -n "$anthropic"; or set anthropic $ANTHROPIC_API_KEY
    set -l venice (envchain ai printenv VENICE_INFERENCE_KEY 2>/dev/null)
    test -n "$venice"; or set venice $VENICE_INFERENCE_KEY

    if test -z "$anthropic"; and test -z "$venice"
        echo "claude: envchain 'ai' is not seeded and no AI keys inherited; run bwseed" >&2
    end

    env ANTHROPIC_API_KEY=$anthropic VENICE_INFERENCE_KEY=$venice \
        $DOTFILES_DIR/secure-claude-code-defaults/bin/claude $argv
end
