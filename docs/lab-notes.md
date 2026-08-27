# Original lab evidence

The source experiment was executed on Windows 11 with WSL2 Ubuntu 24.04, Docker, Minikube, Helm, Open5GS, and UERANSIM.

## Observed success criteria

- The Minikube control plane reached `Ready` with four CPUs and 8192 MiB of memory.
- Open5GS control-plane and user-plane pods reached `Running` in the `open5gs` namespace.
- The UERANSIM gNB and UE pods reached `Running`.
- UE logs reported successful initial registration.
- UE logs reported successful PDU-session establishment.
- `uesimtun0` received an address in the `10.45.0.0/24` range.
- Five ICMP requests to `8.8.8.8` completed with zero packet loss and approximately 30 ms average latency.

## Problems encountered during the experiment

| Symptom | Root cause or practical fix |
| --- | --- |
| `kubectl` not found | Install the Kubernetes CLI and verify it is on `PATH` |
| Helm repository returned `404` | Use the current OCI chart location for Gradiant Open5GS |
| MongoDB remained in init | Check PVC binding, storage provisioner, permissions, and dependent pods |
| `ImagePullBackOff` | Verify the image repository/tag and registry connectivity |
| `ipvlan` address conflict | Remove or redesign N2/N3 secondary-network assignments |
| SCTP failure through a service | Confirm SCTP support; test the AMF endpoint directly when isolating the fault |
| MCC/MNC mismatch | Keep Open5GS, gNB, UE, and subscriber PLMN values identical |
| GTP-U bind failure | Ensure the gNB binds an address present inside its network namespace |
| Missing UPF NAT | Confirm IPv4 forwarding and the UPF masquerade rule |
| PFCP association failure | Inspect both SMF and UPF logs, endpoints, and restart sequencing |

This repository codifies the stable parts of that experiment and keeps topology-specific workarounds in the troubleshooting guide.
