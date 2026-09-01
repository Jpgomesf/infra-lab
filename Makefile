CLUSTER := lab

# Envoy Gateway v1.9.1 (released 2026-08-28). This single manifest also bundles
# the Gateway API v1.6.1 CRDs, so there is no separate CRD install step.
# Server-side apply is required: the CRD schemas are far too large for the
# client-side last-applied annotation.
ENVOY_GATEWAY := https://github.com/envoyproxy/gateway/releases/download/v1.9.1/install.yaml

.PHONY: lab-up lab-down lab-status lab-apply fmt lint

lab-up:
	kind create cluster --config kind.yaml
	kubectl apply --server-side -f $(ENVOY_GATEWAY)
	kubectl -n envoy-gateway-system wait --for=condition=Available \
		deployment/envoy-gateway --timeout=300s
	kubectl apply -k k8s/overlays/local
	kubectl -n app wait --for=condition=Programmed gateway/lab --timeout=180s
	@echo "lab up: http://api.localtest.me  http://mcp.localtest.me  http://grafana.localtest.me  http://minio.localtest.me"

lab-apply:
	kubectl apply -k k8s/overlays/local

lab-status:
	kubectl get pods -A

lab-down:
	kind delete cluster --name $(CLUSTER)

fmt:
	tofu fmt -recursive infra

lint:
	tofu fmt -check -recursive infra
	kubectl kustomize k8s/base > /dev/null
	kubectl kustomize k8s/overlays/local > /dev/null
	@echo "lint OK"
