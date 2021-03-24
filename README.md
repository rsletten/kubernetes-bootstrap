# Bootstrapping k8s using kubeadmin

## Initialize the cluster

```bash
kubeadm init --pod-network-cidr=10.0.0.0/16 (--service-dns-domain=k8s.rsletten.com)
```

## Copy config files to external workstation

```bash
mkdir -p $HOME/.kube
scp root@k8s1:/etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf
```

## Install Calico Networking

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

kubectl taint nodes --all node-role.kubernetes.io/master-

kubectl apply -f https://docs.projectcalico.org/manifests/calicoctl.yaml
```

## Join the other nodes

```bash
ssh root@k8s2 kubeadm join 192.168.1.63:6443 \
--token akb7ie.smob7bl5vmpe6mk2 \
--discovery-token-ca-cert-hash \ sha256:9c6d9253f154a4cea8fc54d2c625d1cc9e957ae5d7df49e9ad584af92c7fd1e1

ssh root@k8s3 kubeadm join 192.168.1.63:6443 \
--token akb7ie.smob7bl5vmpe6mk2 \
--discovery-token-ca-cert-hash \ sha256:9c6d9253f154a4cea8fc54d2c625d1cc9e957ae5d7df49e9ad584af92c7fd1e1

ssh root@k8s4 kubeadm join 192.168.1.63:6443 \
--token akb7ie.smob7bl5vmpe6mk2 \
--discovery-token-ca-cert-hash \ sha256:9c6d9253f154a4cea8fc54d2c625d1cc9e957ae5d7df49e9ad584af92c7fd1e1
```

## label workers

```bash
kubectl label node k8s2.rsletten.com node-role.kubernetes.io/worker=worker
kubectl label node k8s3.rsletten.com node-role.kubernetes.io/worker=worker
kubectl label node k8s4.rsletten.com node-role.kubernetes.io/worker=worker
```

## Install baremetal loadbalancer metallb

```bash
#set strict ARP
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e "s/strictARP: false/strictARP: true/" | kubectl apply -f - -n kube-system

# apply to manifests
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml

# create secret
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

# Create ConfigMap for metallb
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.250-192.168.1.250
EOF
```

## Install ingress-nginx (unless you use traefik)

```bash
wget -q -O -  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/baremetal/deploy.yaml | \
sed -e 's/type: NodePort/type: LoadBalancer/g' | \
kubectl apply -f -
```

## Configure GlusterFS Storage Class

```bash
# create secret
kubectl apply -f gluster-secret.yaml
# create storage class
kubectl apply -f gluster.yaml
# set to default
kubectl patch storageclass slow -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'\n
```

# Traefik v2 + cert-manager

## Create secret

```bash
kubectl apply -f cloudflare.yaml
```

## Install traefik v2

```bash
helm repo add traefik https://containous.github.io/traefik-helm-chart
helm repo update

kubectl create namespace traefik
helm install --namespace traefik traefik traefik/traefik --values values.yaml
```

## Access to the dashboard

```bash
kubectl port-forward -n traefik $(kubectl get pods -n traefik --selector "app.kubernetes.io/name=traefik" --output=name) 9000:9000

wget http://127.0.0.1:9000/dashboard/
```

## Install cert-manager

```bash
# Create the namespace for cert-manager
kubectl create namespace cert-manager

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.2.0 \
  --set installCRDs=true
```

## Verifying the installation

```bash
kubectl get pods --namespace cert-manager
```

## Create cluster issuer

```bash
kubectl apply -f cert-manager/cluster-issuer.yaml
```

## Expose the traefik dashboard

```bash
kubectl apply -f traefik-dashboard-ingress.yaml
```

## Check the certificate issuer with the command:

```bash
echo | openssl s_client -showcerts -servername traefik.k8s.rsletten.com -connect traefik.k8s.rsletten.com:443 2>/dev/null | openssl x509 -inform pem -text
```

## Install the metric server so kubectl top node works

```bash
wget https://github.com/kubernetes-sigs/metrics-server/releases/download/latest/components.yaml

- --kubelet-insecure-tls # add to Deployment containers args
```
