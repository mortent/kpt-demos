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
p "# Create a package with a CloudSQL database and instance"
mkdir sqlpkg && kpt pkg init sqlpkg > /dev/null 2>&1
cat <<EOF >>sqlpkg/sql.yaml
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLDatabase
metadata:
  name: sqldatabase-12
  namespace: config-control
spec:
  charset: utf8mb4
  collation: utf8mb4_bin
  instanceRef:
    name: sqldatabase-instance-12
---
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLInstance
metadata:
  name: sqldatabase-instance-12
  namespace: config-control
spec:
  region: us-central1
  databaseVersion: MYSQL_5_7
  settings:
    tier: db-n1-standard-1
    diskSize: 45
EOF
kpt live init sqlpkg > /dev/null 2>&1
pe "kpt pkg tree sqlpkg"
pe "cat sqlpkg/sql.yaml"
wait

p "# Use the kpt alpha live plan command to perform a preview"
pe "kpt alpha live plan sqlpkg"
wait

p "# Apply the package with kpt live apply"
pe "kpt live apply sqlpkg --server-side"
wait

p "# Update the disk size of the database instance in the package"
pe "kpt fn eval --image gcr.io/kpt-fn/search-replace:unstable -- 'by-path=spec.settings.diskSize' 'by-value=45' 'put-value=90'"
wait

p "# Use the kpt alpha live plan command to see the impact of the change"
pe "kpt alpha live plan sqlpkg"
wait

p "# We want to automate the step of verifying the plan. We can do this by outputting the plan in krm format and use kpt functions to validate the plan."
p "# In this example we use the block-mutation function (https://github.com/mortent/kpt-functions/tree/master/block-mutation) to verify that users never"
p "update the spec.settings.diskSize field on the DatabaseInstance"
cat <<EOF >>fn-config.yaml
apiVersion: v1
kind: BlockMutation
metadata:
  name: block-mutation-config
resourceFields:
- group: sql.cnrm.cloud.google.com
  kind: SQLInstance
  field: spec.settings.diskSize
EOF
p "# The function config for the block-mutation function looks like this:"
pe "cat fn-config.yaml"
wait

p "# We run the plan command with the krm output format and pipe the result into kpt fn eval"
pe "kpt alpha live plan sqlpkg --output=krm | kpt fn eval - --image gcr.io/mortent-dev-kube/block-mutations:unstable --fn-config=fn-config.yaml"
wait

p "# To avoid having to specify the function config every time, we embed the function config in a new image with the"
p "kpt fn embed command (POC: https://github.com/GoogleContainerTools/kpt/pull/3127)"
pe "kpt fn embed gcr.io/mortent-dev-kube/block-mutations:unstable gcr.io/mortent-dev-kube/block-mutations-disksize:unstable --fn-config=fn-config.yaml"
wait

p "# Run the plan command with the new image without specifying the function config"
pe "kpt alpha live plan sqlpkg --output=krm | kpt fn eval - --image gcr.io/mortent-dev-kube/block-mutations-disksize:unstable"
wait

p "# Remove the database resource from the local package and revert the disk size change"
cat <<EOF >sqlpkg/sql.yaml
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLInstance
metadata:
  name: sqldatabase-instance-12
  namespace: config-control
spec:
  region: us-central1
  databaseVersion: MYSQL_5_7
  settings:
    tier: db-n1-standard-1
    diskSize: 45
EOF
pe "cat sqlpkg/sql.yaml"
wait

p "# We run the plan command again to verify that the resource will be pruned"
pe "kpt alpha live plan sqlpkg"
wait
