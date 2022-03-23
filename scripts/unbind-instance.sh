#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
MODULE_DIR=$(cd ${SCRIPT_DIR}/..; pwd -P)

CLUSTER_ID="$1"
INSTANCE_ID="$2"

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

ibmcloud ob monitoring config delete \
  --cluster "${CLUSTER_ID}" \
  --instance "${INSTANCE_ID}" \
  --force || \
  echo "Error deleting monitoring instance from cluster"
