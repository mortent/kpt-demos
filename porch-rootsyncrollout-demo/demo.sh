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

kpt alpha rpkg init foo --repository=blueprint -n default --workspace=foo
kpt alpha rpkg pull blueprint-16f93511a8fd4774c928e09a7e135f9852161f74 -n default ./pull
cat <<EOF >>./pull/cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: foo
  namespace: default
data:
  cm: foo
EOF
kpt alpha rpkg push blueprint-16f93511a8fd4774c928e09a7e135f9852161f74 -n default ./pull
kpt alpha rpkg propose blueprint-16f93511a8fd4774c928e09a7e135f9852161f74 -n default
kpt alpha rpkg approve blueprint-16f93511a8fd4774c928e09a7e135f9852161f74 -n default
rm -fr ./pull


kpt alpha rpkg edit blueprint-16f93511a8fd4774c928e09a7e135f9852161f74 -n default --workspace foo2
kpt alpha rpkg pull blueprint-93dabbfa9de63b507d13d366185a70ee2ed087f7 -n default ./pull
cat <<EOF >./pull/cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: foo2
  namespace: default
data:
  cm: foo2
EOF
kpt alpha rpkg push blueprint-93dabbfa9de63b507d13d366185a70ee2ed087f7 -n default ./pull
kpt alpha rpkg propose blueprint-93dabbfa9de63b507d13d366185a70ee2ed087f7 -n default
kpt alpha rpkg approve blueprint-93dabbfa9de63b507d13d366185a70ee2ed087f7 -n default
rm -fr ./pull


# hide the evidence
clear

pwd

bold=$(tput bold)
normal=$(tput sgr0)

# start demo
clear
p "# We have two KCC ContainerClusters"
pe "kubectl -n config-control get containerclusters"
wait

p "# And a package with two published PackageRevisions"
pe "kpt alpha rpkg get"
wait 2

p "# we create a RootSyncRollout, which specified that all packages in the 'default' namespace should be deployed to all clusters labeled foo=bar"
cat <<EOF >rollout.yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: RootSyncRollout
metadata:
  name: rollout
  namespace: default
spec:
  targets:
    selector:
      matchLabels:
        foo: bar
  packages:
    namespace: default
EOF
pe "cat rollout.yaml"
wait

p "# Tag the first cluster with the required label selector"
pe "kubectl -n config-control label containerclusters.container.cnrm.cloud.google.com gke-one foo=bar"

p "# We apply the RootSyncRollout CR and the latest revision of the 'foo' package is synced to the cluster"
pe "kubectl apply -f rollout.yaml"
sleep 20

p "# We add the label on the second cluster and the same revision of the 'foo' package is synced to that cluster too"
pe "kubectl -n config-control label containerclusters.container.cnrm.cloud.google.com gke-two foo=bar"
sleep 20

p "# We create a new package 'bar' in the default namespace"
kpt alpha rpkg init bar --repository=blueprint -n default --workspace=bar
kpt alpha rpkg pull blueprint-27f109bd9e622b576bbf90394545a8036788694a -n default ./pull
cat <<EOF >>./pull/cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bar
  namespace: default
data:
  cm: bar
EOF
kpt alpha rpkg push blueprint-27f109bd9e622b576bbf90394545a8036788694a -n default ./pull
kpt alpha rpkg propose blueprint-27f109bd9e622b576bbf90394545a8036788694a -n default
kpt alpha rpkg approve blueprint-27f109bd9e622b576bbf90394545a8036788694a -n default
rm -fr ./pull
pe "kpt alpha rpkg get"
sleep 30

p "# We then create a new revision of the 'bar' package and it will be progressively rolled out to all target clusters"
kpt alpha rpkg edit blueprint-27f109bd9e622b576bbf90394545a8036788694a -n default --workspace bar2
kpt alpha rpkg pull blueprint-35712e5fdbb93896693e2bf359d9ce1924413dc4 -n default ./pull
cat <<EOF >./pull/cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bar2
  namespace: default
data:
  cm: bar2
EOF
kpt alpha rpkg push blueprint-35712e5fdbb93896693e2bf359d9ce1924413dc4 -n default ./pull
kpt alpha rpkg propose blueprint-35712e5fdbb93896693e2bf359d9ce1924413dc4 -n default
kpt alpha rpkg approve blueprint-35712e5fdbb93896693e2bf359d9ce1924413dc4 -n default
rm -fr ./pull
pe "kpt alpha rpkg get"
sleep 30

