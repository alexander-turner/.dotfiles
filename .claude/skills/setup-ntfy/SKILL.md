---
name: setup-ntfy
description: Set up ntfy.sh push notifications for the AI safety monitor
activation:
  - /setup-ntfy
  - setup ntfy
  - configure monitor notifications
---

# Setup ntfy.sh

Tell the user to run the setup script directly in their terminal — do NOT run it yourself or attempt to configure ntfy programmatically. The setup must happen outside the monitored model.

Say exactly this:

> Run this in a separate terminal (not through me):
>
> ```bash
> bash bin/setup-ntfy.bash
> ```
>
> This generates a random ntfy topic, writes the config, and tells you how to subscribe on your phone. It needs to run outside of Claude so I can't see or influence the topic.

Do not offer to help with the setup. Do not generate topics. Do not write config files. The whole point is that this runs independently of the monitored model.
