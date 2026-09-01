CLUSTER        := lab
INGRESS_NGINX  := https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/kind/deploy.yaml

.PHONY: lab-up lab-down lab-status lab-apply fmt lint

lab-up:
	kind create cluster --config kind.yaml
	kubectl apply -f $(INGRESS_NGINX)
	kubectl -n ingress-nginx wait --for=condition=Ready pod \
		-l app.kubernetes.io/component=controller --timeout=180s
	kubectl apply -k k8s/overlays/local
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
