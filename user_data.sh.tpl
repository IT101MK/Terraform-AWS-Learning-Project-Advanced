#!/bin/bash
# Runs once, on first boot, as root - same mechanism as the base project.
# The ${host_key} placeholder is what makes each host's page different from
# its siblings, so you can tell them apart in a browser without checking
# the AWS console.
#
# LAB ONLY: this page is served over plain HTTP on port 80 to the whole
# internet (see network.tf). It deliberately shows nothing about the
# environment beyond the host key and hostname - no bucket names, account
# details, or other internal identifiers.

dnf install -y nginx
systemctl enable --now nginx

cat > /usr/share/nginx/html/index.html <<HTML
<!DOCTYPE html>
<html>
  <head><title>Host ${host_key} - Terraform Fleet (lab)</title></head>
  <body style="font-family: sans-serif; text-align: center; margin-top: 15vh;">
    <h1>Host ${host_key}</h1>
    <p>Hostname: $(hostname)</p>
    <p>This host is one member of a Terraform-managed fleet.</p>
    <p><strong>Lab / demo environment only - not a production service.</strong></p>
  </body>
</html>
HTML
