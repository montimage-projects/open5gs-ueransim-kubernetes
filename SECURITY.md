# Security policy

This repository is an educational lab and does not claim production readiness.

## Sensitive data

The checked-in subscriber identity is a public demonstration value. Never commit real subscriber credentials, production PLMN information, private container-registry credentials, kubeconfigs, service-account tokens, or database backups.

Keep the Open5GS WebUI bound to localhost. Do not expose it through a public LoadBalancer, NodePort, or ingress without authentication, TLS, network policy, and a credential review.

## Reporting a vulnerability

Please report security concerns privately through GitHub's security-advisory interface for this repository. Do not open a public issue containing credentials, exploitable endpoints, or subscriber information.
