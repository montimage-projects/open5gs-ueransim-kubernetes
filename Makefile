SHELL := /usr/bin/env bash

.PHONY: preflight cluster deploy verify status webui teardown

preflight:
	./scripts/preflight.sh

cluster:
	./scripts/cluster-up.sh

deploy:
	./scripts/deploy.sh

verify:
	./scripts/verify.sh

status:
	kubectl get pods,svc -n open5gs

webui:
	kubectl port-forward -n open5gs svc/open5gs-webui 9999:9999

teardown:
	./scripts/teardown.sh
