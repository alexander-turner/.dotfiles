#!/bin/bash
# SUDO_ASKPASS helper for brew autoupdate --sudo.
# Pulls the sudo password from envchain so launchd jobs can
# escalate privileges without a GUI password dialog.
#
# One-time setup: envchain --set brew-sudo SUDO_PASSWORD
envchain brew-sudo printenv SUDO_PASSWORD
