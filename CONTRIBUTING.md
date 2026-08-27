# Contributing

Contributions that improve repeatability, observability, compatibility, or documentation are welcome.

## Development workflow

1. Create a focused branch.
2. Keep chart versions explicit and explain version changes.
3. Run `bash -n scripts/*.sh`, ShellCheck, and yamllint before opening a pull request.
4. Never commit real IMSIs, authentication keys, OP/OPc values, kubeconfigs, tokens, or cluster logs containing secrets.
5. Describe the environment used for any end-to-end validation.

Bug reports should include Kubernetes, Minikube, Helm, chart, and container-image versions plus sanitized pod events and logs.
