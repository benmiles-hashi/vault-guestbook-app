vault secrets enable -path=pki pki
vault secrets tune -max-lease-ttl=87600h pki

vault write -field=certificate pki/root/generate/internal \
  common_name="demo-vault-root-ca" ttl=87600h > root_ca.crt

vault write pki/config/urls \
  issuing_certificates="http://vault:8200/v1/pki/ca" \
  crl_distribution_points="http://vault:8200/v1/pki/crl"

vault write pki/roles/webserver \
  allowed_domains="localhost" \
  allow_subdomains=true \
  max_ttl="72h"