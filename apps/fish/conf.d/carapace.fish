# carapace: universal completion engine. Generates completions for ~700
# CLIs from a unified spec, filling in gaps where tools don't ship native
# fish completions. No-op when carapace is missing.
if command -q carapace
    set -gx CARAPACE_BRIDGES 'inshellisense,fish,zsh,bash'
    carapace _carapace fish | source
end
