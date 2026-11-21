#!/usr/bin/env bash
# Build one BAR for the whole legacy estate with ibmint (ACE 12/13 command console).
# For IIB 10 use: mqsipackagebar -a out/hpb.bar -k HPB_CustomerService ...
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out

ibmint package \
  --input-path ../iib \
  --output-bar-file out/hpb.bar \
  --project HPB_CommonLib \
  --project HPB_CustomerService \
  --project HPB_AccountService \
  --project HPB_PaymentService \
  --project HPB_CoreStub

echo "built out/hpb.bar"
echo
echo "Deploy to a standalone integration server work directory:"
echo "  ibmint deploy --input-bar-file out/hpb.bar --output-work-directory /var/hpb/ace-work"
echo "  mqsisetdbparms -w /var/hpb/ace-work -n odbc::HPBDB -u hpb -p hpb"
echo "  IntegrationServer -w /var/hpb/ace-work"
