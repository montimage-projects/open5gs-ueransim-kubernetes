#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${PROFILE:-open5gs-lab}"
CPUS="${CPUS:-4}"
MEMORY="${MEMORY:-2048}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-stable}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
"${script_dir}/preflight.sh"

minikube start \
  --profile "${PROFILE}" \
  --driver docker \
  --cpus "${CPUS}" \
  --memory "${MEMORY}" \
  --kubernetes-version "${KUBERNETES_VERSION}"

minikube profile "${PROFILE}"
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl cluster-info
