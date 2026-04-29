#!/bin/bash
# MedData IAM Lab - Task D: Chroot Jail Provisioning
# Purpose: Build the isolated environment for the Nginx Web Portal

JAIL="/var/chroot/web"

echo "[+] Building jail directories at $JAIL..."
sudo mkdir -p $JAIL/{bin,etc,lib,lib64,usr/lib,var/log/nginx,var/lib/nginx,tmp,dev,run}

echo "[+] Creating system device nodes (null and urandom)..."
sudo mknod -m 666 $JAIL/dev/null c 1 3
sudo mknod -m 666 $JAIL/dev/urandom c 1 9

echo "[+] Setting secure permissions for www-data..."
sudo chown -R www-data:www-data $JAIL/var/log/nginx
sudo chown -R www-data:www-data $JAIL/var/lib/nginx
sudo chmod 1777 $JAIL/tmp

echo "[+] Copying essential system files..."
sudo cp /etc/passwd /etc/group /etc/nsswitch.conf $JAIL/etc/

echo "[!] Jail structure ready. Remember to copy the Nginx binary and libs next."