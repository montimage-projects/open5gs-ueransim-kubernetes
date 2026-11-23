#!/usr/bin/env bash
# Deploy the Montimage Monitoring Tool (MMT) next to the Open5GS lab:
#   1. the mmt chart (MMT-Operator, its MongoDB, Kafka and ZooKeeper) in the
#      MMT_NAMESPACE namespace;
#   2. an MMT-Probe sidecar in the AMF and UPF pods of the open5gs namespace,
#      reporting to that Kafka broker (values/open5gs-mmt-probe.yaml).
#
# Run scripts/deploy.sh first. Re-running scripts/deploy.sh later removes the
# probes again; re-run this script afterwards to restore them.
set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-open5gs}"
OPEN5GS_RELEASE="${OPEN5GS_RELEASE:-open5gs}"
MMT_NAMESPACE="${MMT_NAMESPACE:-mmt}"
MMT_RELEASE="${MMT_RELEASE:-mmt}"
TIMEOUT="${TIMEOUT:-20m}"
KAFKA_WAIT_SECONDS="${KAFKA_WAIT_SECONDS:-300}"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
"${repo_root}/scripts/preflight.sh"

if ! helm status "${OPEN5GS_RELEASE}" --namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "Helm release ${OPEN5GS_RELEASE} not found in ${NAMESPACE}. Run scripts/deploy.sh first." >&2
  exit 1
fi

# 1. MMT back end: operator, MongoDB, Kafka and ZooKeeper.
kubectl create namespace "${MMT_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "${MMT_RELEASE}" "${repo_root}/mmt" \
  --namespace "${MMT_NAMESPACE}" \
  --wait \
  --timeout "${TIMEOUT}"

# A running Kafka container is not yet a working broker: it first has to
# register with ZooKeeper. Wait until it accepts connections so the probes do
# not start against a dead endpoint.
echo "Waiting up to ${KAFKA_WAIT_SECONDS}s for the Kafka broker to listen..."
deadline=$((SECONDS + KAFKA_WAIT_SECONDS))
until kubectl exec kafka --namespace "${MMT_NAMESPACE}" -- \
  bash -c 'exec 3<>/dev/tcp/127.0.0.1/9092' >/dev/null 2>&1; do
  if ((SECONDS >= deadline)); then
    echo 'Kafka did not become reachable in time.' >&2
    kubectl logs kafka --namespace "${MMT_NAMESPACE}" --tail=50 >&2 || true
    exit 1
  fi
  sleep 5
done
echo 'Kafka is reachable.'

# 2. MMT-Probe sidecars in the AMF and UPF pods.
"${repo_root}/scripts/upgrade-open5gs.sh" \
  --values "${repo_root}/values/open5gs-mmt-probe.yaml" \
  --set-string "global.mmtProbe.kafkaHost=kafka.${MMT_NAMESPACE}.svc.cluster.local"

kubectl get pods --namespace "${MMT_NAMESPACE}" -o wide
kubectl get pods --namespace "${NAMESPACE}" -o wide \
  -l "app.kubernetes.io/instance=${OPEN5GS_RELEASE},app.kubernetes.io/name in (amf,upf)"

cat <<EOF

MMT is deployed. Open the MMT-Operator GUI with:
  kubectl port-forward --namespace ${MMT_NAMESPACE} svc/mmt-operator 8080:8080
then visit http://localhost:8080

Probe logs:
  kubectl logs --namespace ${NAMESPACE} deploy/${OPEN5GS_RELEASE}-amf -c mmt-probe
  kubectl logs --namespace ${NAMESPACE} deploy/${OPEN5GS_RELEASE}-upf -c mmt-probe
EOF
