#!/usr/bin/env bash
set -Eeuo pipefail

required=(docker kubectl minikube helm curl)
missing=()

for command_name in "${required[@]}"; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    missing+=("${command_name}")
  fi
done

if ((${#missing[@]} > 0)); then
  printf 'Missing required commands: %s\n' "${missing[*]}" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo 'Docker is installed but its daemon is not reachable.' >&2
  exit 1
fi

echo 'Preflight checks passed.'
printf 'Docker:   %s\n' "$(docker --version)"
printf 'kubectl:  %s\n' "$(kubectl version --client --output=yaml | awk '/gitVersion:/{print $2; exit}')"
printf 'Minikube: %s\n' "$(minikube version --short)"
printf 'Helm:     %s\n' "$(helm version --short)"
