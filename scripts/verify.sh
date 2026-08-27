#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-open5gs}"
TIMEOUT="${TIMEOUT:-10m}"
PING_TARGET="${PING_TARGET:-8.8.8.8}"

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "Namespace ${NAMESPACE} does not exist. Run scripts/deploy.sh first." >&2
  exit 1
fi

kubectl wait \
  --namespace "${NAMESPACE}" \
  --for=condition=Available \
  deployment \
  --all \
  --timeout "${TIMEOUT}"

ue_deployment="$(
  kubectl get deployment -n "${NAMESPACE}" \
    -l app=ueransim,component=ue \
    -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "${ue_deployment}" ]]; then
  echo 'UERANSIM UE deployment was not found.' >&2
  exit 1
fi

ue_logs="$(kubectl logs -n "${NAMESPACE}" "deployment/${ue_deployment}" --tail=300)"

if ! grep -Eqi 'registration is successful|registration accept' <<<"${ue_logs}"; then
  echo 'UE registration success was not found in the logs.' >&2
  exit 1
fi

if ! grep -Eqi 'pdu session.*successful|pdu session establishment accept' <<<"${ue_logs}"; then
  echo 'PDU session success was not found in the logs.' >&2
  exit 1
fi

kubectl exec -n "${NAMESPACE}" "deployment/${ue_deployment}" -- \
  ip address show uesimtun0
kubectl exec -n "${NAMESPACE}" "deployment/${ue_deployment}" -- \
  ping -I uesimtun0 "${PING_TARGET}" -c 5

echo 'End-to-end verification passed.'
