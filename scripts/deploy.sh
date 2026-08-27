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

kubectl get pods -n "${NAMESPACE}" -o wide
