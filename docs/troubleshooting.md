# Troubleshooting

Start with a complete snapshot:

```bash
kubectl get pods,svc,endpoints -n open5gs -o wide
kubectl get events -n open5gs --sort-by=.lastTimestamp
helm list -n open5gs
```

## Pod startup failures

### `ImagePullBackOff`

Inspect the event stream and exact image reference:

```bash
kubectl describe pod -n open5gs <pod-name>
```

Confirm Docker Hub access and the chart/image tag. The UERANSIM chart currently resolves its application image through an upstream `latest` tag, which can change independently of this repository.

### MongoDB stuck in init or pending

Check storage first:

```bash
kubectl get pvc -n open5gs
kubectl describe pvc -n open5gs
kubectl get storageclass
```

On Minikube, verify that the default storage provisioner is enabled and that the node has enough free disk space.

## Registration failures

Read the AMF, gNB, and UE logs together:

```bash
kubectl logs -n open5gs deployment/open5gs-amf --tail=200
kubectl logs -n open5gs deployment/ueransim-gnb --tail=200
kubectl logs -n open5gs deployment/ueransim-ue --tail=200
```

Confirm these values match everywhere:

- MCC: `999`
- MNC: `70`
- TAC: `1`
- SST: `1`
- IMSI/SUPI, subscriber key, OPc, and AMF field

Authentication failures usually mean the subscriber database and UE configuration differ. NG setup failures usually point to the AMF service address, SCTP reachability, or a PLMN/TAC mismatch.

## PDU session succeeds but internet access fails

Confirm the TUN interface and route:

```bash
kubectl exec -n open5gs deployment/ueransim-ue -- ip address show uesimtun0
kubectl exec -n open5gs deployment/ueransim-ue -- ip route
```

Then inspect SMF/UPF state:

```bash
kubectl logs -n open5gs deployment/open5gs-smf --tail=200
kubectl logs -n open5gs deployment/open5gs-upf --tail=200
```

Common causes include a missing PFCP association, GTP-U address advertisement, disabled IPv4 forwarding, or a missing masquerade/NAT rule inside the UPF network namespace.

## Multus and secondary networks

Use Multus only when the cluster topology provides non-overlapping N2 and N3 subnets and the configured `masterIf` exists on every selected node.

Before enabling it:

1. Install a pinned Multus release, not a mutable `master` manifest.
2. Verify the node interface name from inside the Minikube node.
3. Reserve unique N2/N3 ranges that do not overlap Docker, pod, service, host, or VPN networks.
4. Assign AMF and UPF secondary interfaces compatible with the gNB ranges.
5. Enable `global.n2network.enabled` and `global.n3network.enabled` in `values/ueransim.yaml` only after those endpoints exist.

Useful checks:

```bash
minikube ssh --profile open5gs-lab -- ip address
kubectl get network-attachment-definitions -A
kubectl get pod -n open5gs <gnb-pod> -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}'
```

If an `ipvlan` IP conflict appears, stop and redesign the address plan. Repeated restarts will not make a duplicated address safe.
