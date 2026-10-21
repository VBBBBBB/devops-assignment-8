# Assignment 8: Kubernetes Objects, Deployments and Services

Deploy a simple Nginx web application on Kubernetes, expose it through a Service,
provide configuration through a ConfigMap, and demonstrate scaling and rolling
updates - all inside a dedicated Namespace.

## Project Structure
```
Ass8/
├── k8s/
│   ├── namespace.yaml     # Namespace: devops-demo
│   ├── configmap.yaml     # Non-sensitive configuration + custom index.html
│   ├── deployment.yaml    # Nginx Deployment (2 replicas, resource limits)
│   ├── service.yaml       # ClusterIP Service exposing port 80
│   └── kustomization.yaml # Apply everything at once with kustomize
├── REPORT.md
└── README.md
```

## Apply the Manifests
```bash
# Option A: apply individually
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Option B: apply all at once
kubectl apply -k k8s/
```

## Verify
```bash
kubectl get pods -n devops-demo
kubectl get deployments -n devops-demo
kubectl get services -n devops-demo
```

## Scale and Roll Out
```bash
kubectl scale deployment nginx --replicas=3 -n devops-demo
kubectl rollout status deployment/nginx -n devops-demo
kubectl set image deployment/nginx nginx=nginx:1.26 -n devops-demo
```

## Access the Application
```bash
kubectl port-forward svc/nginx-clusterip 8080:80 -n devops-demo
# then open http://localhost:8080
```

## Clean Up
```bash
kubectl delete -k k8s/
```
