#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-open5gs}"
OPEN5GS_RELEASE="${OPEN5GS_RELEASE:-open5gs}"
UERANSIM_RELEASE="${UERANSIM_RELEASE:-ueransim}"
OPEN5GS_CHART_VERSION="${OPEN5GS_CHART_VERSION:-2.3.4}"
UERANSIM_CHART_VERSION="${UERANSIM_CHART_VERSION:-2.0.17}"
TIMEOUT="${TIMEOUT:-20m}"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
"${repo_root}/scripts/preflight.sh"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# clusterIP is immutable: drop a pre-existing non-headless UPF PFCP service so
# Helm can recreate it headless, then restart the SMF to re-resolve it.
upf_pfcp_svc="${OPEN5GS_RELEASE}-upf-pfcp"
restart_pfcp=false
current_cluster_ip="$(kubectl get service "${upf_pfcp_svc}" -n "${NAMESPACE}" \
  -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)"
if [[ -n "${current_cluster_ip}" && "${current_cluster_ip}" != "None" ]]; then
  kubectl delete service "${upf_pfcp_svc}" -n "${NAMESPACE}"
  restart_pfcp=true
fi

helm upgrade --install "${OPEN5GS_RELEASE}" \
  oci://registry-1.docker.io/gradiantcharts/open5gs \
  --namespace "${NAMESPACE}" \
  --version "${OPEN5GS_CHART_VERSION}" \
  --values "${repo_root}/values/open5gs.yaml" \
  --wait \
  --timeout "${TIMEOUT}"

kubectl rollout status "deployment/${OPEN5GS_RELEASE}-amf" \
  --namespace "${NAMESPACE}" \
  --timeout "${TIMEOUT}"

if [[ "${restart_pfcp}" == true ]]; then
  # Only the SMF needs a restart: it resolves the UPF address once at startup.
  # The UPF pod is unchanged and accepts the new SMF association as is.
  kubectl rollout restart "deployment/${OPEN5GS_RELEASE}-smf" --namespace "${NAMESPACE}"
  kubectl rollout status "deployment/${OPEN5GS_RELEASE}-smf" \
    --namespace "${NAMESPACE}" --timeout "${TIMEOUT}"
fi

helm repo add towards5gs \
  https://raw.githubusercontent.com/Orange-OpenSource/towards5gs-helm/main/repo/ \
  --force-update
helm repo update towards5gs

helm upgrade --install "${UERANSIM_RELEASE}" towards5gs/ueransim \
  --namespace "${NAMESPACE}" \
  --version "${UERANSIM_CHART_VERSION}" \
  --values "${repo_root}/values/ueransim.yaml" \
  --wait \
  --timeout "${TIMEOUT}"

# The towards5gs chart only accepts a literal gtpIp. With 0.0.0.0 the gNB
# advertises 0.0.0.0 as its N3 address and the UPF sends downlink GTP-U to
# itself. Substitute the pod IP at container start instead.
# The chart also gives no pull policy for its wait-amf init container, whose
# image is tagged latest and therefore defaults to Always: every gNB restart
# would download it again. Pin it to IfNotPresent.
gnb_deployment="${UERANSIM_RELEASE}-gnb"
gnb_config="/ueransim/config/gnb-config.yaml"
kubectl patch deployment "${gnb_deployment}" -n "${NAMESPACE}" --type=json -p "[
  {\"op\": \"add\", \"path\": \"/spec/template/spec/initContainers/0/imagePullPolicy\", \"value\": \"IfNotPresent\"},
  {\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/env\",
   \"value\": [{\"name\": \"POD_IP\", \"valueFrom\": {\"fieldRef\": {\"fieldPath\": \"status.podIP\"}}}]},
  {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/command\", \"value\": [\"/bin/sh\", \"-c\"]},
  {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/args\",
   \"value\": [\"sed \\\"s/^gtpIp:.*/gtpIp: \${POD_IP}/\\\" ${gnb_config} > /tmp/gnb-config.yaml && exec ./nr-gnb -c /tmp/gnb-config.yaml\"]}
]"
kubectl rollout status "deployment/${gnb_deployment}" \
  --namespace "${NAMESPACE}" --timeout "${TIMEOUT}"

# Restart the UE so it registers against the (possibly restarted) gNB.
kubectl rollout restart "deployment/${UERANSIM_RELEASE}-ue" --namespace "${NAMESPACE}"
kubectl rollout status "deployment/${UERANSIM_RELEASE}-ue" \
  --namespace "${NAMESPACE}" --timeout "${TIMEOUT}"

kubectl get pods -n "${NAMESPACE}" -o wide
