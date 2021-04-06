# Traefik v2

## Install traefik v2

```bash
helm repo add traefik https://containous.github.io/traefik-helm-chart
helm repo update

kubectl create namespace traefik
helm install --namespace traefik traefik traefik/traefik --values treafik-values.yaml
```

## Access to the dashboard

```bash
kubectl port-forward -n traefik $(kubectl get pods -n traefik --selector "app.kubernetes.io/name=traefik" --output=name) 9000:9000

wget http://127.0.0.1:9000/dashboard/
```

## Expose the traefik dashboard

```bash
kubectl apply -f traefik-dashboard-ingress-tls.yaml
```

## Check the certificate issuer with the command:

```bash
echo | openssl s_client -showcerts -servername traefik.k8s.rsletten.com -connect traefik.k8s.rsletten.com:443 2>/dev/null | openssl x509 -inform pem -text
```
