#!/bin/bash

# Installing watsonx.data, watson studio, spark

# Ensure required environment variables are set
REQUIRED_VARS=(OCP_USERNAME OCP_PASSWORD OCP_URL VERSION PROJECT_CPD_INST_OPERATORS PROJECT_CPD_INST_OPERANDS STG_CLASS_BLOCK STG_CLASS_FILE)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Error: Environment variable ${var} is not set"
    exit 1
  fi
done

# Function to login to OCP
login_ocp() {
  echo "Logging in to OCP..."
  cpd-cli manage login-to-ocp \
    --username="${OCP_USERNAME}" \
    --password="${OCP_PASSWORD}" \
    --server="${OCP_URL}"
  
  if [ $? -ne 0 ]; then
    echo "Error logging in to OCP"
    exit 1
  fi
}

# Function to apply OLM
apply_olm() {
  local component=$1
  echo "Applying OLM for component: ${component}"
  cpd-cli manage apply-olm \
    --release="${VERSION}" \
    --cpd_operator_ns="${PROJECT_CPD_INST_OPERATORS}" \
    --components="${component}"
  
  if [ $? -ne 0 ]; then
    echo "Error applying OLM for component: ${component}"
    exit 1
  fi
}

# Function to apply CR
apply_cr() {
  local component=$1
  echo "Applying CR for component: ${component}"
  cpd-cli manage apply-cr \
    --components="${component}" \
    --release="${VERSION}" \
    --cpd_instance_ns="${PROJECT_CPD_INST_OPERANDS}" \
    --block_storage_class="${STG_CLASS_BLOCK}" \
    --file_storage_class="${STG_CLASS_FILE}" \
    --license_acceptance=true
  
  if [ $? -ne 0 ]; then
    echo "Error applying CR for component: ${component}"
    exit 1
  fi
}

# Function to verify installation
verify_installation() {
  local component=$1
  echo "Verifying installation for component: ${component}"
  cpd-cli manage get-cr-status \
    --cpd_instance_ns="${PROJECT_CPD_INST_OPERANDS}" \
    --components="${component}"
  
  if [ $? -ne 0 ]; then
    echo "Error verifying installation for component: ${component}"
    exit 1
  fi
}

# ####################################################################
# Installation of services - MODIFY AS NEEDED
# ####################################################################

# Login to OCP
login_ocp

# Installing watsonx_ai
apply_olm "watsonx_ai"
apply_cr "watsonx_ai"

# Installing watsonx_data
apply_olm "watsonx_data"
apply_cr "watsonx_data"

# Verifying installations
verify_installation "datastage_ent"
verify_installation "ws_pipelines"
verify_installation "db2wh"

echo "Installation and verification completed successfully."