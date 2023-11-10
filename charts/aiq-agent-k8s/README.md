# AttackIQ Endpoint Agent in Kubernetes

![Version: 3.8.11](https://img.shields.io/badge/Version-3.8.11-informational?style=flat-square)

This is a helm chart for provisioning an AttackIQ endpoint agent into a k8s cluster.

Agents are provisioned via a StatefulSet. By default, only one agent will be started.

## Prerequisites

* Kubernetes cluster where you want to install the agent.
* System that has appropriate roles and permissions on the cluster. This is where we will install the helm chart.
* The appropriate versions of `helm` and `kubectl` for your environment on that system.
* A valid auth token and platform address for the agent.

## Repo

`helm repo add attackiq https://helm-charts.attackiq.net/`

To refresh the repo (get new helm charts):

`helm repo refresh`

To see which version of the chart you have:

`helm search repo | grep aiq-agent-k8s`

## Configure

First create a new namespace if you don't already have it.

`kubectl create namespace aiq-agent-k8s`

Next you will need to supply an agent configuration file. Here is an example template.

```
global:
  auth-token: <AUTH_TOKEN>
  platform-address: <PLATFORM_ADDRESS>
  platform-port: 443
  use-https: true
  verify-ssl: true
  update-policy: disabled
0:
  guid: <YOUR_GUID>
```

* AUTH_TOKEN will be your agent authorization token obtained from the platform.
* PLATFORM_ADDRESS will be the location of your AttackIQ server. For SaaS (cloud), use firedrill.attackiq.com.
* YOUR_GUID is a unique identifier specific to your config. You may pick whatever value you want as long as it is random and not shared by any other agent.

Fill the above file out and save it somewhere safe. It must be named `config.yml` for the following step.

This example will assume that you saved the file to your current working directory.

Issue the following command:

`kubectl create configmap agent-config --from-file=config.yml -n aiq-agent-k8s`

You are now ready to install the helm chart.

## Install

`helm install --debug aiq-agent-k8s attackiq/aiq-agent-k8s --create-namespace --namespace aiq-agent-k8s --wait --timeout 10m`

When this command finishes, you should have a pod named `aiq-agent-k8s-0` running the agent. Check the logs on the pod for any errors or agent messages.

Note that while we have given a `--timeout` of `10m`, depending on the speed of your network, it may take longer to pull the initial image which is a few hundred
megabytes in size.
If the above command times out, check the status with `kubectl get pods -n aiq-agent-k8s` and `kubectl describe pod <pod_name> -n aiq-agent-k8s` to see the
specific status of the pod. 

## Uninstall

`helm uninstall --debug aiq-agent-k8s -n aiq-agent-k8s`

This will remove the chart and all chart-managed resources. The agent config file will remain behind unless you remove it yourself.

If you want to delete the agent configuration, use this command:

`kubectl delete configmap agent-config -n aiq-agent-k8s`

## Troubleshooting

### Config

If you get an error when trying to start the deployment that looks like this:

```
Warning  FailedMount  22s (x7 over 53s)  kubelet MountVolume.SetUp failed for volume "config-volume" : configmap "agent-config" not found 
```

It means that you have not added the agent config (see above). Double check your setup:

`kubectl get configmap agent-config -n aiq-agent-k8s`

Should return something like the following:

```
NAME           DATA   AGE
agent-config   1      23s
```

You can directly examine the config map contents with the following:

`kubectl get configmap agent-config -n aiq-agent-k8s -o yaml`

### Other

If the deployment is in an unrecoverable state such as `ImagePullBackoff`, you may delete the deployment with helm (see Uninstall),
fix the issue, and reinstall it.