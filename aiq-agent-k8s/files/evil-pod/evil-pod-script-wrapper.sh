#!/bin/bash
#
# wrap the invocation of evil-pod script, which is much more complicated
# and mounted in a volume. use this wrapper if configuring via script scenario
# execution.
#
script=/etc/evil-pod/evil-pod.sh
if [[ -e $script ]]; then
  bash $script
else
  exit 1
fi