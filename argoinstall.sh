#! /bin/sh

set -e
set -x

REPO_URL="https://github.com/israelsz/argocd-gitops.git"

if [ -z "${REPO_TOKEN}" ]; then
  echo "REPO_TOKEN is not set. Please set it before running this script"
  exit 1
fi

# Installs Argo CD with the official chart + our values
helm upgrade --install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --namespace argocd --create-namespace \
  --version 8.3.0 \
  --set crds.install=true \
  -f infra/argocd/values.yaml
  
# Wait for the ArgoCD server to be ready
kubectl wait -n argocd --for=condition=available deployment/argocd-server --timeout=180s

# Create the secret to allow ArgoCD to access the GitHub repo
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: github-argocd-repo-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: ${REPO_URL}
  username: argo-bootstrap
  password: ${REPO_TOKEN}
EOF

# Bootstrap the infra application -> ArgoCD starts managing itself
# Also deploys the other infra apps
kubectl apply -n argocd -f infra-bootstrap.yaml