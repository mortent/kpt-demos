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
p "# get kafka"
pe "kpt pkg get https://github.com/mortent/kpt-packages/kafka@v0.1 kafka"
wait

p "# get zookeeper as a subpackage of kafka"
pe "kpt pkg get https://github.com/mortent/kpt-packages/zookeeper@v0.1 kafka/zookeeper"
wait

p "# show package hierarchy"
pe "kpt pkg tree kafka"
wait

# Changing the namespace causes problems, so we don't do this for now.
#
# p "# change namespace for kafka by adding the set-namespace function to the root (kafka) package"
# pe "gsed '/mutators:/a\  - name: set-namespace\n    image: gcr.io/kpt-fn/set-namespace:unstable\n    configMap:\n      namespace: staging' -i kafka/Kptfile"

# p "# change namespace for zookeeper by adding the set-namespace function to the zookeeper package"
# pe "gsed '/mutators:/a\  - name: set-namespace\n    image: gcr.io/kpt-fn/set-namespace:unstable\n    configMap:\n      namespace: staging' -i kafka/zookeeper/Kptfile"

p "# add a label to all resources in the packages"
pe "gsed '/mutators:/a\  - name: set-label\n    image: gcr.io/kpt-fn/set-label:unstable\n    configMap:\n      app.kubernetes.io/part-of: demo' -i kafka/Kptfile"
wait

p "# run the pipeline"
pe "kpt fn render kafka"
wait

# As explained above, changing namespace is problematic
#
# p "# namespace has changed for kafka resources"
# pe "grep 'namespace:' kafka/*.yaml"
# pe "grep -A 2 'KAFKA_CFG_ADVERTISED_LISTENERS' kafka/*.yaml"
#
# p "# namespace has changed for zookeeper resources"
# pe "grep 'namespace:' kafka/zookeeper/*.yaml"
# pe "grep -A 2 'ZOO_SERVERS' kafka/zookeeper/*.yaml"

p "# label has been added to all resources in kafka and zookeeper packages"
pe "grep 'app.kubernetes.io/part-of' kafka/*.yaml"
pe "grep 'app.kubernetes.io/part-of' kafka/zookeeper/*.yaml"
wait

p "# commit the package"
pe "git add . && git commit -m 'first commit of demo package'"
wait

p "# manually change the desired version of the Zookeeper package"
pe "gsed 's/ref: v0.1/ref: master/g' -i kafka/zookeeper/Kptfile"
wait

p "# commit the change"
pe "git add . && git commit -m 'update desired version of Zookeeper packages'"
wait

p "# update the kafka package, which will also update the zookeeper package since we have changed the Kptfile"
pe "kpt pkg update kafka@master"
wait

p "# show package hierarchy"
pe "kpt pkg tree kafka"
wait

p "# labels from both upstream and local"
pe "grep -A 4 -m 1 'labels:' kafka/statefulset.yaml"
wait
