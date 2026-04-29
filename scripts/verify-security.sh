#!/bin/bash
# MedData IAM Lab - Security Audit Script
# Purpose: Verify isolation and access controls

echo "--- SECURITY AUDIT REPORT ---"

echo "[1] Checking Nginx Chroot Isolation..."
NGINX_PID=$(pgrep nginx | head -1)
if [ -z "$NGINX_PID" ]; then
    echo "[!] ERROR: Nginx is not running."
else
    sudo ls /proc/$NGINX_PID/root/ | grep -E "home|data" > /dev/null
    if [ $? -eq 1 ]; then
        echo "[SUCCESS] Nginx process cannot see /home or /data (Isolated)."
    else
        echo "[FAILURE] Nginx process can see sensitive root directories!"
    fi
fi

echo "[2] Testing ACL Access for 'staff' group..."
sudo -u staff_user1 ls /data/patient_records 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[SUCCESS] Staff user denied access to patient records."
else
    echo "[FAILURE] Staff user can read patient records!"
fi

echo "--- AUDIT COMPLETE ---"