#!/usr/bin/env bash
# Send a sample request through API Connect (or straight to IIB with DIRECT=1).
#   ./call.sh payment/InitiateTransfer-ok.xml
# Env: GATEWAY (default https://localhost:9444/hpb), CLIENT_ID, CLIENT_SECRET, TOKEN (payments only)
set -euo pipefail
cd "$(dirname "$0")/requests"
file="$1"; svc="${file%%/*}"
case "$svc" in customer) path=CustomerService;; account) path=AccountService;; payment) path=PaymentService;; esac
if [ "${DIRECT:-0}" = 1 ]; then
  # IIB direct: no gateway, so supply the channel in the request header (already set to WEB in the samples)
  curl -sS -X POST "http://localhost:7800/$svc" -H 'Content-Type: text/xml' -H 'SOAPAction: ""' --data @"$file"
else
  curl -ksS -X POST "${GATEWAY:-https://localhost:9444/hpb}/$svc/$path" \
    -H 'Content-Type: text/xml' -H 'SOAPAction: ""' \
    -H "X-IBM-Client-Id: ${CLIENT_ID:?set CLIENT_ID}" -H "X-IBM-Client-Secret: ${CLIENT_SECRET:?set CLIENT_SECRET}" \
    ${TOKEN:+-H "Authorization: Bearer $TOKEN"} --data @"$file"
fi
echo
