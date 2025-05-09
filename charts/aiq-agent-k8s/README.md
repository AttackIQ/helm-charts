# AttackIQ Endpoint Agent in Kubernetes

![App: 3.9.60-1](https://img.shields.io/badge/App_Version-3.9.60--1-informational?style=flat-square)
![Chart: 0.4.11-beta](https://img.shields.io/badge/Chart_Version-0.4.11--beta-informational?style=flat-square)

This is a helm chart for provisioning an AttackIQ endpoint agent into a k8s cluster.

## Prerequisites

* Kubernetes cluster where you want to install the agent.
* System that has appropriate roles and permissions on the cluster. This is where we will install the helm chart.
* The appropriate versions of `helm` and `kubectl` for your environment on that system.
* A valid auth token and platform address for the agent.

## Deployment Requirements

* This chart is designed to be deployed in a namespace dedicated to the agent. This is to avoid conflicts with other resources in the cluster.
* AttackIQ strongly recommends to deploy the agent into a staging environment first to ensure that it is working as expected before deploying into a production environment.
* The agent must be deployed in a location where it can reach the AttackIQ platform, whether you are using the platform from the cloud or on-premises.

### Tool Versions

These are the tool versions used to develop and deploy the chart. Your kubernetes should at least be on version `v1.26` -- use earlier releases at your own risk! 
While you may use the cluster of your choice when selecting a staging environment, we recommend using `minikube` for local testing.

* `kubectl`: at least `v1.26.1`
* `helm`: at least `v3.11.2`
* `minikube`: at least `v1.29.0` (staging/local only)

## Repo

`helm repo add attackiq https://helm-charts.attackiq.net/`

To refresh the repo (get new helm charts):

`helm repo update`

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

### Setting Replica Count
If you wish to have more than one agent, make sure you have the following:
* In your configuration map for the agent, make sure to assign a GUID to the agent slot. These are numbered starting from 0. If you do not assign one, the pod will be provisioned with a random GUID.
* When you install the chart per the above, add the argument `--set replicaCount=N`, where N is the number of agents that you want. The default is 1 unless this value is overridden.

### Setting GUID

Pre-populating the GUID in the agent configmap is recommended, but not required. If you do not pre-populate the GUID, the 
agent will generate a random GUID for itself. This means that if the chart is re-provisioned, such as in an update, the
GUID will change and the agent will be treated as a new install by the platform. This can have undesirable effects on
reporting, which is why we are recommending (but not enforcing) that you pre-populate the GUID.

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

### Agent

Agent logs may be viewed by running the following command. Any connection or communications errors the agent encounters will be logged here.

`kubectl logs aiq-agent-k8s-0 -n aiq-agent-k8s`

If you have provisioned more than one agent, replace the `0` with the appropriate number.

### Cluster

* If the deployment is in an unrecoverable state such as `ImagePullBackoff`, you may delete the deployment with helm (see Uninstall),
fix the issue, and reinstall it.
* If the initial image pull seems to be taking a long time, describe the pod to see if there are any errors. Otherwise, you may have a slow network connection.
