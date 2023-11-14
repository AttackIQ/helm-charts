#!/bin/bash
k=kubectl
IN_K8S=0 # whether we are inside a k8s pod or not.
IN_SS=0  # whether the hostname format matches the "StatefulSets" convention.
ORD=0    # which pod we are currently on (by ordinal)

[[ -n $KUBERNETES_SERVICE_HOST ]] && IN_K8S=1
[[ $(hostname) =~ -([0-9]+)$ ]] && IN_SS=1

if [[ $IN_SS == 1 && $IN_K8S == 1 ]]; then
  echo "Detected stateful set pod running in k8s"
  ORD=${BASH_REMATCH[1]}
  echo "Using ORD=$ORD as the config identifier"
else
  echo "Not running in k8s. Agent not configured."
  tail -F /dev/null
fi

AGENT_DIR=/opt/attackiq/agent
AGENT=${AGENT_DIR}/ai_exec_server
AGENT_CONFIG=${AGENT_DIR}/config.yml
AGENT_RESTART=${AGENT_DIR}/ai-agent-restart.sh
CONFIG_MAP=/etc/agent-config/config.yml
IDV2=/opt/attackiq/agent-data/idv2
YQ=/usr/bin/yq

if [[ ! -f $CONFIG_MAP ]]; then
  echo "*** ERROR"
  echo "*** Config map $CONFIG_MAP not found!"
  echo "*** An agent configuration must be supplied!"
  echo "*** See https://github.com/AttackIQ/helm-charts/tree/main/charts/aiq-agent-k8s/README.md for setup instructions!"
  tail -F /dev/null
fi

# get value from config map
function get_config_map_value {
  local key=$1
  VAL=$($YQ eval "${key}" $CONFIG_MAP)
}

# write update into agent configuration
function update_agent_config_value {
  local value=$1
  $YQ eval "$value" $AGENT_CONFIG -i
}

# uses mounted secrets to make a default kubeconfig
function init_kubeconfig {
  crt="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  tok="/var/run/secrets/kubernetes.io/serviceaccount/token"
  if [[ ! -e $crt || ! -e $tok ]]; then
    echo "init_kubeconfig: ERROR: $crt / $tok do not exist"
    return
  fi
  if [[ -n $KUBERNETES_SERVICE_HOST && -n $KUBERNETES_PORT_443_TCP_PORT ]]; then
    kurl="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT"
    $k config set-cluster default --server=$kurl --certificate-authority=$crt --embed-certs=true
    kt=$(cat $tok)
    $k config set-credentials default --token=$kt
    $k config set-context default --cluster default --user default
    $k config use-context default
    $k get pods
    # shellcheck disable=SC2181
    if [[ "$?" != 0 ]]; then
      echo "init_kubeconfig: ERROR: kubeconfig setup failed, could not query cluster!"
      return
    fi
  else
    echo "init_kubeconfig: ERROR: cannot discern environment (KUBERNETES_SERVICE_HOST/KUBERNETES_PORT_443_TCP_PORT not set)"
  fi
}

function save_kenv {
  outfile="/etc/aiq_kenv"
  env | grep -E '^KUBERNETES' > $outfile
  sed -i 's/\(^KUBERNETES.*\)/export \1/g' $outfile
}

echo "Generating base agent config..."
$AGENT --write-config

echo "Getting guid from config map..."
get_config_map_value ".${ORD}.guid"
guid=$VAL
if [[ -n $guid && $guid != "null" ]]; then
  echo "$guid" > $IDV2
  echo "Set guid to $guid"
else
  echo "Error: cannot find a guid for pod ${ORD} -- must be added to config map."
  tail -F /dev/null
fi

# get and update the rest of the agent configuration
get_config_map_value ".global.auth-token"
auth_token=$VAL
echo "Auth token=$auth_token"
update_agent_config_value ".auth-token = \"${auth_token}\""

get_config_map_value ".global.platform-address"
platform_address=$VAL
echo "Platform address=$platform_address"
update_agent_config_value ".platform-address = \"${platform_address}\""

get_config_map_value ".global.platform-port"
platform_port=$VAL
echo "Platform port=$platform_port"
update_agent_config_value ".platform-port = ${platform_port}"

get_config_map_value ".global.use-https"
use_https=$VAL
echo "Use https=$use_https"
update_agent_config_value ".use-https = ${use_https}"

get_config_map_value ".global.verify-ssl"
verify_ssl=$VAL
echo "Verify ssl=$verify_ssl"
update_agent_config_value ".verify-ssl = ${verify_ssl}"

get_config_map_value ".global.update-policy"
update_policy=$VAL
echo "Update policy=$update_policy"
update_agent_config_value ".update-policy = \"${update_policy}\""

echo "Setting up kubeconfig"
init_kubeconfig

echo "Saving kenv"
save_kenv

echo "Starting agent service"
$AGENT_RESTART

echo "Tailing agent log..."
tail -F /var/log/attackiq/aiq_agent_go.log