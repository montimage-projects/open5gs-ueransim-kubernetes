#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-open5gs}"
PROFILE="${PROFILE:-open5gs-lab}"
DELETE_CLUSTER="${DELETE_CLUSTER:-false}"

if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  helm uninstall ueransim --namespace "${NAMESPACE}" --ignore-not-found
  helm uninstall open5gs --namespace "${NAMESPACE}" --ignore-not-found
  kubectl delete namespace "${NAMESPACE}" --wait=true
else
  echo "Namespace ${NAMESPACE} is already absent."
fi

if [[ "${DELETE_CLUSTER}" == "true" ]]; then
  minikube delete --profile "${PROFILE}"
fi
