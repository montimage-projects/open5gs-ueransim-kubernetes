#!/usr/bin/env bash
# Remove the MMT-Probe sidecars from the AMF and UPF pods, then the MMT
# release and its namespace. The Open5GS and UERANSIM releases stay deployed.
set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-open5gs}"
OPEN5GS_RELEASE="${OPEN5GS_RELEASE:-open5gs}"
MMT_NAMESPACE="${MMT_NAMESPACE:-mmt}"
MMT_RELEASE="${MMT_RELEASE:-mmt}"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if helm status "${OPEN5GS_RELEASE}" --namespace "${NAMESPACE}" >/dev/null 2>&1; then
  # Upgrading with the base values only drops the sidecars.
  "${repo_root}/scripts/upgrade-open5gs.sh"
else
  echo "Helm release ${OPEN5GS_RELEASE} is absent; no probes to remove."
fi

if kubectl get namespace "${MMT_NAMESPACE}" >/dev/null 2>&1; then
  helm uninstall "${MMT_RELEASE}" --namespace "${MMT_NAMESPACE}" --ignore-not-found
  kubectl delete namespace "${MMT_NAMESPACE}" --wait=true
else
  echo "Namespace ${MMT_NAMESPACE} is already absent."
fi
