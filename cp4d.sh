#!/bin/bash

# Setup Bastion Machine
export BASTION_HOST=${BASTION_HOST}
ssh root@${BASTION_HOST}

#Install OC on Bastion Server => https://www.ibm.com/docs/en/cloud-paks/cp-data/5.0.x?topic=workstation-installing-openshift-cli
export OPENSHIFT_BASE_DOMAIN=<CHANGE_ME>
wget --no-check-certificate https://downloads-openshift-console.apps.${OPENSHIFT_BASE_DOMAIN}/amd64/linux/oc.tar
tar -xvf oc.tar
chmod +x oc
sudo mv oc /usr/local/bin/oc

# Install container runtime alternatively you can install podman (sudo yum install -y podman)
sudo -i <<EOF
yum update -y
yum upgrade -y
yum install -y podman
EOF

# Setting up a client workstation

# Download Version 13.1.5 of the `cpd-cli` => https://github.com/IBM/cpd-cli/releases
wget https://github.com/IBM/cpd-cli/releases/download/v14.0.1/cpd-cli-linux-EE-14.0.1.tgz

# Extract the contents of the package to the directory where you want to run the `cpd-cli`. => https://www.ibm.com/docs/en/cloud-paks/cp-data/5.0.x?topic=workstation-installing-cloud-pak-data-cli
tar xzvf cpd-cli-linux-EE-14.0.1.tgz
sudo mv cpd-cli-linux-EE-14.0.1 /opt/
sudo rm -rf /opt/cpd-cli-linux-EE
sudo ln -s /opt/cpd-cli-linux-EE-14.0.1/ /opt/cpd-cli-linux-EE

# Add the following line to your `~/.bash_profile` file:
cat << EOF >> ~/.bash_profile
export PATH=\${PATH}:/opt/cpd-cli-linux-EE
EOF

# Run this command to reload/gain access to the cpd-cli command for the user
source ~/.bash_profile

# Run the following command to ensure that the `cpd-cli` is installed and running and that the `cpd-cli` manage plug-in has the latest version of the `olm-utils` image.
cpd-cli manage restart-container

# Creating an environment variables file. get entitlement key from => https://myibm.ibm.com/products-services/containerlibrary
cat << EOF > ./cpd_vars.sh
# IBM Entitled Registry
export IBM_ENTITLEMENT_KEY=get it from 
# Cluster
export OCP_URL=api.ocpinstall.gym.lan:6443
export OCP_USERNAME=kubeadmin
export OCP_PASSWORD=CH7rE-stQkY-fQZCg-HMfqB
export OPENSHIFT_TYPE=self-managed
export IMAGE_ARCH=amd64
# Projects
export PROJECT_CERT_MANAGER=ibm-cert-manager
export PROJECT_LICENSE_SERVICE=ibm-licensing
export PROJECT_SCHEDULING_SERVICE=cpd-scheduler
export PROJECT_CPD_INST_OPERATORS=cpd-operators
export PROJECT_CPD_INST_OPERANDS=cpd-instance
# Storage
export STG_CLASS_BLOCK=ocs-storagecluster-ceph-rbd
export STG_CLASS_FILE=ocs-storagecluster-cephfs
# Cloud Pak for Data version
export VERSION=4.8.5
EOF

# you can edit the file
touch cpd_vars.sh

# Confirm that the script does not contain any errors.
bash ./cpd_vars.sh

# If you stored passwords in the file, prevent others from reading the file.
chmod 700 cpd_vars.sh

# Source the environment variables.
source ./cpd_vars.sh

# check access to cp.icr.io (IBM Container Registry)
echo "alias docker=podman" >> ~/.bashrc
source ~/.bashrc
docker login -u cp -p $IBM_ENTITLEMENT_KEY cp.icr.io

# Updating the global image pull secret for IBM Cloud Pak for Data

# Log in to the cluster as a user with sufficient permissions to complete this task.
cpd-cli manage login-to-ocp \
  --username=${OCP_USERNAME} \
  --password=${OCP_PASSWORD} \
  --server=${OCP_URL}

# Provide your IBM entitlement API key to the global image pull secret:
cpd-cli manage add-icr-cred-to-global-pull-secret \
  --entitled_registry_key=${IBM_ENTITLEMENT_KEY}

# Get the status of the nodes.
cpd-cli manage oc get nodes

# This command patches the specified KubeletConfig to set the pod PIDs limit to 16384
oc patch kubeletconfig ${KUBELET_CONFIG} \
--type=merge \
--patch='{"spec":{"kubeletConfig":{"podPidsLimit":16384}}}'

# This command retrieves the status of all MachineConfigPools (MCP) in the OpenShift cluster
oc get mcp

# Create the required projects:
oc login --username=${OCP_USERNAME} --password=${OCP_PASSWORD} --server=${OCP_URL}
oc new-project ${PROJECT_CERT_MANAGER}
oc new-project ${PROJECT_LICENSE_SERVICE}
oc new-project ${PROJECT_SCHEDULING_SERVICE}

# This command retrieves the status of all KubeletConfig resources in the OpenShift cluster
# If no KubeletConfig is defined, the command will return an empty list.
oc get kubeletconfig

# If no KubeletConfig is found, create a new one. Replace <desired-name> with your preferred name.
# You can skip this step if a KubeletConfig already exists.
oc create -f - <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: <desired-name>
spec:
  machineConfigPoolSelector:
    matchLabels:
      custom-kubelet: "true"
  kubeletConfig:
    podPidsLimit: 4096  # Initial pod PIDs limit, this can be patched later
EOF

# Note the instance name from the output above and export it here
# Replace <kubeletconfig-name> with the actual name of your KubeletConfig
export KUBELET_CONFIG=<kubeletconfig-name>

# Log in to the cluster as a user with sufficient permissions to complete this task.
cpd-cli manage login-to-ocp \
  --username=${OCP_USERNAME} \
  --password=${OCP_PASSWORD} \
  --server=${OCP_URL}

# Install the Certificate manager and the License Service:
cpd-cli manage apply-cluster-components \
  --release=${VERSION} \
  --license_acceptance=true \
  --cert_manager_ns=${PROJECT_CERT_MANAGER} \
  --licensing_ns=${PROJECT_LICENSE_SERVICE}

# Install the scheduling service:
cpd-cli manage apply-scheduler \
  --release=${VERSION} \
  --license_acceptance=true \
  --scheduler_ns=${PROJECT_SCHEDULING_SERVICE}

# Log in to the cluster as a user with sufficient permissions to complete this task.
cpd-cli manage login-to-ocp \
  --username=${OCP_USERNAME} \
  --password=${OCP_PASSWORD} \
  --server=${OCP_URL}

# Apply the CRI-O settings:
cpd-cli manage apply-crio \
  --openshift-type=${OPENSHIFT_TYPE}

# Log in to the cluster as a user with sufficient permissions to complete this task.
cpd-cli manage login-to-ocp \
  --username=${OCP_USERNAME} \
  --password=${OCP_PASSWORD} \
  --server=${OCP_URL}

# Apply the required permissions to the projects.
cpd-cli manage authorize-instance-topology \
  --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}

# Log in to the cluster as a user with sufficient permissions to complete this task.
cpd-cli manage login-to-ocp \
  --username=${OCP_USERNAME} \
  --password=${OCP_PASSWORD} \
  --server=${OCP_URL}

# Install IBM Cloud Pak foundational services and create the required ConfigMap:
cpd-cli manage setup-instance-topology \
  --release=${VERSION} \
  --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
  --license_acceptance=true \
  --block_storage_class=${STG_CLASS_BLOCK}

# Check shared service components
cpd-cli manage get-cr-status --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}

# Log in to the cluster as a user with sufficient permissions to complete this task.
cpd-cli manage login-to-ocp \
  --username=${OCP_USERNAME} \
  --password=${OCP_PASSWORD} \
  --server=${OCP_URL}

# Review the license terms for Cloud Pak for Data.
cpd-cli manage get-license \
  --release=${VERSION} \
  --license-type=EE

# Install the operators in the operators project for the instance.
cpd-cli manage apply-olm \
  --release=${VERSION} \
  --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
  --components=cpd_platform

# Install the operands in the operands project for the instance.
cpd-cli manage apply-cr \
  --release=${VERSION} \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
  --components=cpd_platform,,watsonx_ai \
  --block_storage_class=${STG_CLASS_BLOCK} \
  --file_storage_class=${STG_CLASS_FILE} \
  --license_acceptance=true

# Confirm that the status of the operands is Completed:
cpd-cli manage get-cr-status --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}

# Get the URL of the web client and the automatically generated password for the admin user
cpd-cli manage get-cpd-instance-details --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} --get_admin_initial_credentials=true