# IBM Cloud Pak for Data Setup and Installation Guide

This `README.md` provides instructions for setting up and installing IBM Cloud Pak for Data (CPD) on an OpenShift cluster using a bash script. Follow the steps below to configure your environment and deploy CPD.

## Prerequisites

- **Bastion Host**: Ensure you have access to a bastion host.
- **OpenShift Cluster**: You need an OpenShift cluster to install CPD.
- **IBM Entitlement Key**: Obtain your IBM Entitlement Key from [IBM Container Library](https://myibm.ibm.com/products-services/containerlibrary).

## Script Overview

This script performs the following actions:

1. Setup Bastion Machine
2. Install OpenShift CLI (`oc`)
3. Install Container Runtime (`podman`)
4. Setup Client Workstation
5. Create and Source Environment Variables
6. Login to IBM Container Registry
7. Update Global Image Pull Secret
8. Patch KubeletConfig
9. Create Projects
10. Install Certificate Manager, License Service, and Scheduling Service
11. Apply CRI-O Settings
12. Authorize Instance Topology
13. Setup IBM Cloud Pak for Data Instance
14. Install IBM Cloud Pak Operators and Operands
15. Retrieve CPD Instance Details
