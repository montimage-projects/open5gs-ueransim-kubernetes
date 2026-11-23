#!/usr/bin/env bash
# Upgrade the existing open5gs release with values/open5gs.yaml plus any extra
# Helm arguments given on the command line, then restart the dependents of the
# AMF and UPF if those pods were replaced:
#   - UPF replaced: its pod IP changes and the SMF resolves it only at startup.
#   - AMF replaced: the gNB loses its NG (SCTP) association and does not
#     reconnect on its own.
#   - Either replaced: the UE must register and open a new PDU session.
#
# Used by scripts/deploy-mmt.sh and scripts/teardown-mmt.sh. Run
# scripts/deploy.sh first: it creates the release and the UERANSIM workloads.
set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-open5gs}"
OPEN5GS_RELEASE="${OPEN5GS_RELEASE:-open5gs}"
UERANSIM_RELEASE="${UERANSIM_RELEASE:-ueransim}"
OPEN5GS_CHART_VERSION="${OPEN5GS_CHART_VERSION:-2.3.4}"
TIMEOUT="${TIMEOUT:-20m}"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if ! helm status "${OPEN5GS_RELEASE}" --namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "Helm release ${OPEN5GS_RELEASE} not found in ${NAMESPACE}. Run scripts/deploy.sh first." >&2
  exit 1
fi

generation() {
  kubectl get deployment "$1" --namespace "${NAMESPACE}" \
    -o jsonpath='{.metadata.generation}' 2>/dev/null || true
}

restart() {
  kubectl rollout restart "deployment/$1" --namespace "${NAMESPACE}"
  kubectl rollout status "deployment/$1" --namespace "${NAMESPACE}" --timeout "${TIMEOUT}"
}

amf="${OPEN5GS_RELEASE}-amf"
upf="${OPEN5GS_RELEASE}-upf"
amf_before="$(generation "${amf}")"
upf_before="$(generation "${upf}")"

helm upgrade "${OPEN5GS_RELEASE}" \
  oci://registry-1.docker.io/gradiantcharts/open5gs \
  --namespace "${NAMESPACE}" \
  --version "${OPEN5GS_CHART_VERSION}" \
  --values "${repo_root}/values/open5gs.yaml" \
  "$@" \
  --wait \
  --timeout "${TIMEOUT}"

kubectl rollout status "deployment/${amf}" --namespace "${NAMESPACE}" --timeout "${TIMEOUT}"
kubectl rollout status "deployment/${upf}" --namespace "${NAMESPACE}" --timeout "${TIMEOUT}"

amf_changed=false
upf_changed=false
[[ "$(generation "${amf}")" != "${amf_before}" ]] && amf_changed=true
[[ "$(generation "${upf}")" != "${upf_before}" ]] && upf_changed=true

if [[ "${upf_changed}" == true ]]; then
  restart "${OPEN5GS_RELEASE}-smf"
fi

if [[ "${amf_changed}" == true ]]; then
  restart "${UERANSIM_RELEASE}-gnb"
fi

if [[ "${amf_changed}" == true || "${upf_changed}" == true ]]; then
  ue_selector='app=ueransim,component=ue'
  mapfile -t old_ue_pods < <(kubectl get pods --namespace "${NAMESPACE}" \
    -l "${ue_selector}" -o name)
  restart "${UERANSIM_RELEASE}-ue"
  # The UE ignores SIGTERM, so the old pod lingers for its grace period.
  # Wait it out: `kubectl exec deployment/...` (scripts/verify.sh) could
  # otherwise land on the old pod, which has no uesimtun0 anymore.
  if ((${#old_ue_pods[@]} > 0)); then
    kubectl wait --for=delete --namespace "${NAMESPACE}" \
      --timeout "${TIMEOUT}" "${old_ue_pods[@]}"
  fi
else
  echo 'AMF and UPF pods unchanged; no dependent restarts needed.'
fi
