#!/bin/bash
set -e

# ---------------------------------------------------------
# Install OpenTofu
# ---------------------------------------------------------
echo "==> Installing OpenTofu..."

# Install from official APT repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://get.opentofu.org/opentofu.gpg | sudo tee /etc/apt/keyrings/opentofu.gpg > /dev/null
curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | sudo gpg --no-tty --batch --dearmor -o /etc/apt/keyrings/opentofu-repo.gpg > /dev/null
sudo chmod a+r /etc/apt/keyrings/opentofu.gpg /etc/apt/keyrings/opentofu-repo.gpg

echo \
  "deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | \
  sudo tee /etc/apt/sources.list.d/opentofu.list > /dev/null

sudo apt-get update
sudo apt-get install -y tofu

echo "OpenTofu version: $(tofu --version)"

# ---------------------------------------------------------
# Install additional tools
# ---------------------------------------------------------
echo "==> Installing tflint..."
curl -fsSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

echo "==> Installing tfsec..."
curl -fsSL -o /tmp/tfsec https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64
sudo install -o root -g root -m 0755 /tmp/tfsec /usr/local/bin/tfsec
rm /tmp/tfsec

echo ""
echo "==> Tool versions:"
echo "  OpenTofu:  $(tofu --version | head -1)"
echo "  AWS CLI:   $(aws --version)"
echo "  kubectl:   $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo "  Helm:      $(helm version --short)"
echo "  tflint:    $(tflint --version)"
echo "  tfsec:     $(tfsec --version 2>/dev/null || echo 'installed')"
echo ""
echo "==> Done! Infrastructure dev environment is ready."
