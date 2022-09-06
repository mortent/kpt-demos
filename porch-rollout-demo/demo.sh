#!/bin/bash
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export PROMPT_TIMEOUT=1

########################
# include the magic
########################
. demo-magic.sh

# cd $(mktemp -d)
mkdir demo
cd demo
git init

# create the namespace we will be using
kubectl create ns foo

# hide the evidence
clear

pwd

bold=$(tput bold)
normal=$(tput sgr0)

# start demo
clear
p "# We have two packages, foo and bar, where foo has been published but bar has not"
pe "kpt alpha rpkg get"
wait

p "# Both contain only a single ConfigMap"
pe "kpt alpha rpkg pull blueprint-91817620282c133138177d16c981cf35f0083cad -n default"
wait 2
pe "kpt alpha rpkg pull blueprint-b47eadc99f3c525571d3834cc61b974453bc6be2 -n default"
wait

p "# We have two clusters created with Config Connnector. They both have ACM installed"
p "# Only cluster gke-one has the label deploy-packages=true"
pe "k -n config-control get containerclusters.container.cnrm.cloud.google.com --show-labels"
wait

p "# Create a rollout to deploy all packages in the default namespace to all cluster matching our label selector"
cat <<EOF >rollout.yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: RootSyncRollout
metadata:
  name: demo-rollout
  namespace: default
spec:
  targets:
  - clusterType: configConnector
    selector:
      matchLabels:
        deploy-packages: "true"
  packages:
    namespace: default
EOF
pe "cat rollout.yaml"
wait

p "# Apply the rollout CR"
pe "k apply -f rollout.yaml"
wait

pe "sleep 5"

p "# We can see that a RootSyncSet for package-cluste combination has been created"
pe "k get rootsyncsets -A"
wait

p "# We can also see that the package has been installed in the gke-one cluster"
pe "k config use-context gke_mortent-dev-kube_us-central1_gke-one"
pe "k -n config-management-system get rootsync foo-gke-one"
pe "k get cm foo"
wait

p "# Switch back to our Config Controller cluster"
pe "k config use-context gke_mortent-dev-kube_us-central1_krmapihost-config-controller-test"
wait

p "# We add the deploy-package=true label to the gke-two cluster"
pe "k label containerclusters.container.cnrm.cloud.google.com gke-two deploy-packages=true"
wait

p "# We publish the bar package"
pe "kpt alpha rpkg propose blueprint-b47eadc99f3c525571d3834cc61b974453bc6be2 -n default"
pe "kpt alpha rpkg approve blueprint-b47eadc99f3c525571d3834cc61b974453bc6be2 -n default"
wait

pe "sleep 30"

p "# We can see that the needed RootSyncSets have been created (currently only using one cluster per RootSyncSet)"
pe "k get rootsyncsets -A"
wait
