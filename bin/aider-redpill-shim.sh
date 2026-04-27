#!/bin/sh
# Re-export the Redpill API key under OPENAI_API_KEY so Aider's OpenAI
# client targets Redpill's OpenAI-compatible endpoint, then exec the
# command passed in $@.
#
# Invoked via:
#   envchain ai -- bin/aider-redpill-shim.sh /path/to/aider [aider args...]
#
# envchain populates REDPILL_API_KEY and friends in the environment; this
# script just remaps and execs. No user input is concatenated into any
# shell string.

export OPENAI_API_KEY="$REDPILL_API_KEY"
export OPENAI_API_BASE="https://api.redpill.ai/v1"
export AIDER_MODEL="openai/anthropic/claude-sonnet-4.5"
exec "$@"
