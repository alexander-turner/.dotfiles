---
name: setup-ntfy
description: Configure ntfy.sh push notifications for the AI safety monitor
activation:
  - /setup-ntfy
  - setup ntfy
  - configure monitor notifications
  - monitor push notifications
---

# Setup ntfy.sh for the AI Safety Monitor

Configure push notifications so the monitor can alert you on your phone when it flags suspicious AI behavior (ASK-tier escalations).

## Steps

1. Generate a random, unguessable topic name:
   ```bash
   TOPIC=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))")
   echo "Your topic: $TOPIC"
   ```

2. Write the config file:
   ```bash
   mkdir -p ~/.config/claude-monitor
   cat > ~/.config/claude-monitor/ntfy.conf <<EOF
   topic=$TOPIC
   url=https://ntfy.sh
   EOF
   ```

3. Tell the user to subscribe to the topic on their phone:
   - Install the [ntfy app](https://ntfy.sh) (iOS / Android)
   - Add the topic shown above
   - Send a test notification to verify:
     ```bash
     curl -d "Monitor test — if you see this, notifications work!" "ntfy.sh/$TOPIC"
     ```

4. Remind the user: in the devcontainer, `harden-monitor.bash` will automatically chown this file to `root:root 600` on next container start so the monitored model can't read the topic.

## Important

- The topic name is a shared secret — anyone who knows it can send you notifications. Keep it unguessable.
- Do NOT echo the topic into Claude's output after setup. Print it once for the user to copy, then stop.
- If the user already has a topic (e.g., self-hosted ntfy), just ask them for the topic and URL and write the config file.
