#!/bin/bash
# MedData IAM Lab - MFA Audit
# Purpose: Extract Google Authenticator success logs

echo "[+] Recent MFA Authentication Successes:"
sudo grep "google_authenticator" /var/log/auth.log | grep "accepted" | tail -n 5

if [ $? -ne 0 ]; then
    echo "[-] No recent MFA successes found in logs."
fi