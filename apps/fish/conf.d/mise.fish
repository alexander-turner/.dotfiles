# Activate mise (replaces nvm/asdf/pyenv/rbenv) when installed. mise injects
# its shims and overrides PATH so per-directory .tool-versions / mise.toml
# files take effect transparently. Idempotent: a no-op when mise is missing.
if command -q mise
    mise activate fish | source
end
