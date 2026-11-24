#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${PROFILE:-open5gs-lab}"
CPUS="${CPUS:-4}"
MEMORY="${MEMORY:-3048}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-stable}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
# MMT security rules on this host, bind-mounted into the Minikube node so the
# AMF MMT-Probe can mount them through a hostPath volume (scripts/deploy-mmt.sh).
# Minikube applies the mount only when it creates the node container: on an
# existing cluster, changing it requires DELETE_CLUSTER=true scripts/teardown.sh.
MMT_RULES_DIR="${MMT_RULES_DIR:-${repo_root}/mmt/security-rules}"
MMT_RULES_NODE_DIR="${MMT_RULES_NODE_DIR:-/mmt/security-rules}"

"${script_dir}/preflight.sh"

mkdir -p "${MMT_RULES_DIR}"

minikube start \
  --profile "${PROFILE}" \
  --driver docker \
  --cpus "${CPUS}" \
  --memory "${MEMORY}" \
  --kubernetes-version "${KUBERNETES_VERSION}" \
  --mount-string "${MMT_RULES_DIR}:${MMT_RULES_NODE_DIR}"

minikube profile "${PROFILE}"
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl cluster-info
