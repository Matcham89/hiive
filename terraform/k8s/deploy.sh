#!/usr/bin/env bash
set -euo pipefail

TERRAFORM_VERSION="1.9.8"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install Terraform to ~/bin if not already present
if ! command -v terraform &>/dev/null; then
  echo "Terraform not found — installing v${TERRAFORM_VERSION} to ~/bin"
  mkdir -p ~/bin
  curl -fsSLo /tmp/terraform.zip \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
  unzip -o /tmp/terraform.zip -d ~/bin/
  rm /tmp/terraform.zip
  echo "Terraform installed: $(terraform version -json | python3 -c 'import sys,json; print(json.load(sys.stdin)["terraform_version"])')"
else
  echo "Terraform found: $(terraform version -json | python3 -c 'import sys,json; print(json.load(sys.stdin)["terraform_version"])')"
fi

cd "$SCRIPT_DIR"

echo ""
echo "==> terraform init"
terraform init

echo ""
echo "==> terraform apply"
terraform apply

echo ""
echo "==> Configuring kubectl"
aws eks update-kubeconfig --name hiive --region us-east-1

echo ""
echo "==> Verifying pods"
kubectl get pods -n hello-world
