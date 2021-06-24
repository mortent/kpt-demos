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

# hide the evidence
clear

pwd

bold=$(tput bold)
normal=$(tput sgr0)

# start demo
clear
p "# get wordpress"
pe "kpt pkg get https://github.com/GoogleContainerTools/kpt.git/package-examples/wordpress@v0.7"
wait

p "# show package hierarchy"
pe "kpt pkg tree wordpress"
wait

p "# commit the package before we make changes"
pe "git add . && git commit -m 'commit wordpress package'"
wait

p "# add a label to all resources in the package"
pe "kpt fn eval wordpress --image gcr.io/kpt-fn/set-label:v0.1 -- app.kubernetes.io/part-of=demo"
wait

p "# add a demo prefix to all resources in the package"
pe "kpt fn eval wordpress --image gcr.io/kpt-fn/ensure-name-substring:v0.1 -- prepend=demo-"
wait

p "# update the version of wordpress and add an extra env variable to the wordpress container spec (imagine doing this in vim)"
pe "gsed -ri 's/^(\s*)(image: wordpress:4.8-apache$)/\1image: wordpress:4.9-apache/' wordpress/deployment/deployment.yaml"
pe "gsed '/env:/a\            - name: DB_USER\n              value: mysql-user' -i wordpress/deployment/deployment.yaml"
wait

p "# put all resources in the demo namespace by adding it to the package pipeline"
pe "gsed '/mutators:/a\    - image: gcr.io/kpt-fn/set-namespace:v0.1\n      configMap:\n        namespace: demo' -i wordpress/Kptfile"
wait

p "# run the pipeline"
pe "kpt fn render wordpress"
wait

p "# show the diff from our changes"
pe "git --no-pager diff"
wait

p "# commit the package"
pe "git add . && git commit -m 'commit the changes to the package before update'"
wait

p "# update the package"
pe "kpt pkg update wordpress@v0.8"
wait

p "# show the changes merged in from upstream"
pe "git --no-pager diff"
wait

p "# commit the changes"
pe "git add . && git commit -m 'commit updated package'"
wait
