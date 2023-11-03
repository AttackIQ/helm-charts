# AttackIQ Endpoint Agent in Kubernetes

![Version: 3.8.11](https://img.shields.io/badge/Version-3.8.11-informational?style=flat-square)

*Work In Progress*

This is a helm chart for provisioning an AttackIQ endpoint agent into a k8s cluster.

Agents are provisioned via a StatefulSet and come with core set of helper scripts for test content.

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

`helm install --debug aiq-agent-k8s attackiq/aiq-agent-k8s --create-namespace --namespace aiq-agent-k8s --wait`

When this command finishes, you should have a pod named `aiq-agent-k8s-0` running the agent. Check the logs on the pod for any errors or agent messages.

## Uninstall

`helm uninstall --debug aiq-agent-k8s -n aiq-agent-k8s`

This will remove the chart and all chart-managed resources. The agent config file will remain behind unless you remove it yourself.

If you want to delete the agent configuration, use this command:

`kubectl delete configmap agent-config -n aiq-agent-k8s`