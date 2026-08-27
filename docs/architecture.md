# Architecture

## Control plane

Open5GS implements the 5G Standalone core as independently deployable network functions. Kubernetes provides scheduling, DNS, service discovery, restart behavior, and a stable virtual service address for each function.

| Interface | Endpoints | Protocol | Purpose |
| --- | --- | --- | --- |
| N1 | UE - AMF (via gNB) | NAS | Registration and session signaling |
| N2 | gNB - AMF | NGAP over SCTP | Access-network control plane |
| SBI | Core network functions | HTTP/2 + JSON | Service discovery and NF-to-NF signaling |
| N4 | SMF - UPF | PFCP | User-plane session programming |

The UERANSIM gNB reaches `open5gs-amf-ngap:38412` through an SCTP Kubernetes Service. Core NFs find one another through cluster DNS and the NRF/SCP service-based architecture.

## User plane

The UE creates `uesimtun0` after registration and PDU-session establishment. Packets follow this path:

```text
application
  -> uesimtun0 in the UERANSIM UE pod
  -> simulated radio link to the gNB
  -> N3 / GTP-U tunnel to the UPF
  -> Open5GS data network and NAT
  -> external network
```

The lab validates the path with an ICMP echo request sourced explicitly from `uesimtun0`.

## Why the default does not enable Multus

Separate Multus interfaces are architecturally closer to a telecom deployment, but local Minikube clusters frequently expose only a virtual `eth0`. Statically assigning secondary `ipvlan`/`macvlan` addresses can then collide with node or Docker networks.

This repository therefore uses the primary pod network by default. The protocol boundaries remain visible, while the local setup avoids topology-specific addresses. See [Troubleshooting](troubleshooting.md#multus-and-secondary-networks) before enabling secondary networks.
