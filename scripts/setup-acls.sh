#!/bin/bash
# MedData IAM Lab - Task A: ACL Automation
# Purpose: Configure granular permissions for medical records

echo "[+] Creating directory structure..."
sudo mkdir -p /data/patient_records/sensitive

echo "[+] Setting group ownership to 'doctors'..."
sudo chown root:doctors /data/patient_records
sudo chmod 750 /data/patient_records

echo "[+] Applying ACLs for audit_user (Read-Only)..."
sudo setfacl -m u:audit_user:r-x /data/patient_records
sudo setfacl -R -m u:audit_user:r-- /data/patient_records/sensitive

echo "[+] Explicitly blocking 'staff' group..."
sudo setfacl -m g:staff:--- /data/patient_records

echo "[+] Setting Default ACLs for future files..."
sudo setfacl -d -m u:audit_user:r-- /data/patient_records
sudo setfacl -d -m g:staff:--- /data/patient_records

echo "[!] ACL Setup Complete. Use 'getfacl /data/patient_records' to verify."