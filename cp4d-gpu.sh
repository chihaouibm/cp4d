#!/bin/bash

# Create a namespace for the Node Feature Discovery (NFD) Operator
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-nfd
EOF

# Create an OperatorGroup for the NFD Operator
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  generateName: openshift-nfd-
  name: openshift-nfd
  namespace: openshift-nfd
spec:
  targetNamespaces:
  - openshift-nfd 
EOF

# Create a Subscription for the NFD Operator
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfd
  namespace: openshift-nfd
spec:
  channel: "stable"
  installPlanApproval: Automatic
  name: nfd
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Check pod status for NFD
oc get pods -n openshift-nfd

# Create the NodeFeatureDiscovery Custom Resource
oc apply -f - <<EOF
apiVersion: nfd.openshift.io/v1
kind: NodeFeatureDiscovery
metadata:
  name: nfd-instance
  namespace: openshift-nfd
spec:
  instance: "" # instance is empty by default
  topologyupdater: false # False by default
  operand:
    image: registry.redhat.io/openshift4/ose-node-feature-discovery:v4.12
    imagePullPolicy: Always
  workerConfig:
    configData: |
      core:
        sleepInterval: 60s
      sources:
        cpu:
          cpuid:
            attributeBlacklist:
              - "BMI1"
              - "BMI2"
              - "CLMUL"
              - "CMOV"
              - "CX16"
              - "ERMS"
              - "F16C"
              - "HTT"
              - "LZCNT"
              - "MMX"
              - "MMXEXT"
              - "NX"
              - "POPCNT"
              - "RDRAND"
              - "RDSEED"
              - "RDTSCP"
              - "SGX"
              - "SSE"
              - "SSE2"
              - "SSE3"
              - "SSE4.1"
              - "SSE4.2"
              - "SSSE3"
EOF

# Check pod status again for NFD
oc get pods -n openshift-nfd

# Create a namespace for the NVIDIA GPU Operator
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: nvidia-gpu-operator
EOF

# Create an OperatorGroup for the NVIDIA GPU Operator
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nvidia-gpu-operator-group
  namespace: nvidia-gpu-operator
spec:
  targetNamespaces:
  - nvidia-gpu-operator
EOF

# Extract the channel version for GPU Operator installation
export CHANNEL=$(oc get packagemanifest gpu-operator-certified -n openshift-marketplace -o jsonpath='{.status.defaultChannel}')
export CURRENT_CSV=$(oc get packagemanifests/gpu-operator-certified -n openshift-marketplace -ojson | jq -r '.status.channels[] | select(.name == "'$CHANNEL'") | .currentCSV')

# Create a Subscription for the NVIDIA GPU Operator
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: nvidia-gpu-operator
spec:
  channel: "${CHANNEL}"
  installPlanApproval: Manual
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
  startingCSV: "${CURRENT_CSV}"
EOF

# Verify and approve the install plan
export INSTALL_PLAN=$(oc get installplan -n nvidia-gpu-operator -oname)
oc patch $INSTALL_PLAN -n nvidia-gpu-operator --type merge --patch '{"spec":{"approved":true }}'

# Create the ClusterPolicy for NVIDIA GPU Operator
oc get csv -n nvidia-gpu-operator $CURRENT_CSV -ojsonpath={.metadata.annotations.alm-examples} | jq .[0] > clusterpolicy.json
oc apply -f clusterpolicy.json

# Test GPU detection by creating a sample pod
oc apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cuda-vectoradd
spec:
  restartPolicy: OnFailure
  containers:
  - name: cuda-vectoradd
    image: "nvidia/samples:vectoradd-cuda11.2.1"
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

# Check the logs for the CUDA test pod
oc logs cuda-vectoradd
