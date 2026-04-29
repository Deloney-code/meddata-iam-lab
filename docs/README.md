Based on everything we did in this lab, here is exactly what goes in your README. Since you are on Windows PowerShell in VS Code, create the file by clicking **New File** in the Explorer panel, name it `README.md`, then paste this content:

---

```markdown
# MedData Research Hospital — IAM Lab Scenario 2

![Ubuntu](https://img.shields.io/badge/Platform-Ubuntu_24.04-E95420?style=for-the-badge&logo=ubuntu)
![Security](https://img.shields.io/badge/Domain-Cybersecurity-red?style=for-the-badge)
![Compliance](https://img.shields.io/badge/Compliance-GDPR%20%2F%20HIPAA-blue?style=for-the-badge)
![Status](https://img.shields.io/badge/Lab_Status-Completed-brightgreen?style=for-the-badge)

---

## What This Lab Is About

This is a hands-on cybersecurity lab where I act as part of a Cybersecurity Response Team
hired to fix critical Identity and Access Management violations at MedData Research Hospital.
The hospital manages sensitive patient records on Ubuntu servers and was found to be
in violation of both HIPAA and GDPR regulations.

All four tasks were implemented and verified on Ubuntu 24.04 LTS.

---

## The Problem

An internal audit found four critical security violations:

| # | Violation | Regulation Broken |
|---|-----------|------------------|
| 1 | The `staff` group had broad read access to `/data/patient_records` — every staff member could read all patient files | HIPAA Minimum Necessary Rule |
| 2 | Admins used the same credentials for the public web server and the secure patient database | HIPAA Access Control |
| 3 | No time-of-day restrictions — staff could log in at 3AM from home with no oversight | HIPAA Audit Controls |
| 4 | The nginx web portal process had full access to the entire server filesystem | GDPR Article 32 |

---

## Lab Environment

| Machine | OS | IP Address | Role |
|---------|----|-----------|----|
| Ubuntu Server | Ubuntu 24.04 | 192.168.116.144 | All tasks — Bastion, Secure Zone, Web Portal, Patient Records |
| Windows Host | Windows 11 | 192.168.116.1 | External tester |

### Users and Groups Created

| User | Group | Role | Access |
|------|-------|------|--------|
| `audit_user` | — | Compliance auditor | Read-only on patient records |
| `staff_user1` | `staff` | Hospital staff | Blocked from patient records |
| `doctor1` | `doctors` | Medical doctor | Full access to patient records |
| `attacker` | `sudo`, `bastion_users` | System admin | Full access via bastion + MFA |

---

## Task A — Linux ACLs (Access Control Lists)

### Why
Standard Linux UGO permissions (User-Group-Others) could not handle the granularity needed.
We needed to give `audit_user` read-only access without adding them to the `doctors` group,
and block the `staff` group without changing file ownership.
ACLs let us set per-user and per-group rules independently of ownership.

### What I Did
- Created `/data/patient_records` owned by the `doctors` group
- Used `setfacl` to give `audit_user` read-only access via ACL
- Used `setfacl` to explicitly deny the `staff` group
- Set default ACLs so new files inherit permissions automatically
- Applied recursively to all existing files with `-R`

### Commands Used
```bash
sudo apt install -y acl
sudo mkdir -p /data/patient_records/sensitive
sudo chown root:doctors /data/patient_records
sudo chmod 750 /data/patient_records

# audit_user — read only
sudo setfacl -m u:audit_user:r-x /data/patient_records
sudo setfacl -m u:audit_user:r-x /data/patient_records/sensitive
sudo setfacl -R -m u:audit_user:r-- /data/patient_records/sensitive

# doctors — full access
sudo setfacl -m g:doctors:rwx /data/patient_records

# staff — explicitly blocked
sudo setfacl -m g:staff:--- /data/patient_records

# default ACL for new files
sudo setfacl -d -m u:audit_user:r-- /data/patient_records
sudo setfacl -d -m g:staff:--- /data/patient_records
sudo setfacl -R -m u:audit_user:r-- /data/patient_records/

getfacl /data/patient_records
```

### Verification
| Test | Command | Result |
|------|---------|--------|
| audit_user reads file | `sudo -u audit_user cat /data/patient_records/sensitive/record1` | ✅ Shows file content |
| audit_user writes file | `sudo -u audit_user bash -c 'echo hack > record1'` | ✅ Permission denied |
| staff_user1 lists dir | `sudo -u staff_user1 ls /data/patient_records` | ✅ Permission denied |
| doctor1 creates file | `sudo -u doctor1 bash -c 'echo note > doctor_note.txt'` | ✅ Success |

### Screenshots
![ACL Setup](screenshots/TaskA-01-directory-setup-acl-commands.png)
![ACL Verification](screenshots/TaskA-02-getfacl-output-and-verification.png)

### Key Lesson Learned
Default ACLs only apply to new files created after the ACL is set.
Files that already existed need `setfacl -R` to apply permissions retroactively.
Also — every directory in the path needs execute permission, not just the final one.
`/data/patient_records` AND `/data/patient_records/sensitive` both needed explicit ACL entries.

---

## Task B — PAM Time-of-Day Restrictions

### Why
PAM (Pluggable Authentication Modules) sits between the user and the OS.
Every service — SSH, console login, sudo — goes through PAM.
By adding `pam_time.so` we enforce time rules at the kernel authentication layer,
before any application even sees the login request.
This directly addresses the 3AM access problem found in the audit.

### What I Did
- Installed `libpam-modules`
- Added time rules to `/etc/security/time.conf`
- Enabled `pam_time.so` in `/etc/pam.d/sshd` and `/etc/pam.d/login`
- Verified by adding a temporary blocking rule for the current hour and testing login

### Configuration

**`/etc/security/time.conf`**
```
sshd;*;%staff;Wk0800-2000
sshd;*;%doctors;Wk0700-2100
sshd;*;audit_user;Wk0800-1800
login;*;!root;!Al0000-0600
```

**`/etc/pam.d/sshd`** and **`/etc/pam.d/login`** — added after `@include common-auth`:
```
account    required    pam_time.so
```

### Verification
Auth log confirmed denial at the preauth stage:
```
fatal: Access denied for user staff_user1
by PAM account configuration [preauth]
```

| Test | Result |
|------|--------|
| Login during allowed hours | ✅ Permitted |
| Login during blocked hours | ✅ Denied before password prompt |
| Auth log evidence | ✅ PAM denial recorded |

### Screenshots
![PAM login config](screenshots/TaskB-01-pam-login-conf-with-pam-time.png)
![PAM install and time.conf](screenshots/TaskB-02-libpam-install-time-conf-edited.png)
![time.conf rules](screenshots/TaskB-03-time-conf-rules-staff-doctors-audit.png)
![Login allowed](screenshots/TaskB-04-staff-user1-login-allowed-then-exit.png)
![Login denied](screenshots/TaskB-05-staff-user1-login-denied-blocked-hours.png)
![Auth log denial](screenshots/TaskB-06-authlog-pam-access-denied-preauth.png)

---

## Task C — Bastion Host with MFA

### Why
A Bastion Host (Jump Server) is the single hardened entry point to the Secure Zone.
Combined with Multi-Factor Authentication (TOTP via Google Authenticator), it ensures:
- Something you **have** — SSH private key
- Something you **possess** — time-based one-time password from your phone

Even if an attacker steals the private key, they still cannot access the Secure Zone
without the physical authenticator device.

### Architecture
```
Windows Host (192.168.116.1)
         |
         |  Step 1: SSH private key
         |  Step 2: Google Authenticator TOTP code
         v
  [BASTION — port 22]
  AuthenticationMethods publickey,keyboard-interactive
  pam_google_authenticator.so required
         |
         |  ProxyJump (internal only)
         v
  [SECURE ZONE — port 2222]
  AllowUsers *@127.0.0.1
  UFW: DENY 2222 from anywhere except 127.0.0.1
```

### What I Did
- Installed `libpam-google-authenticator` and generated TOTP secret + QR code
- Added `pam_google_authenticator.so` as first line in `/etc/pam.d/sshd`
- Configured `/etc/ssh/sshd_config` to require key + TOTP
- Created a second sshd instance on port 2222 for the Secure Zone
- Blocked port 2222 externally with UFW, allowed only from `127.0.0.1`
- Configured ProxyJump on Windows `~/.ssh/config`

### Key Config Files

**`/etc/pam.d/sshd`** — first line:
```
auth required pam_google_authenticator.so nullok
```

**`/etc/ssh/sshd_config`** — Bastion:
```
AuthenticationMethods publickey,keyboard-interactive
KbdInteractiveAuthentication yes
PasswordAuthentication no
AllowGroups bastion_users sudo
PermitRootLogin no
LogLevel VERBOSE
```

**`/etc/ssh/sshd_config_secure`** — Secure Zone:
```
Port 2222
AuthenticationMethods publickey
KbdInteractiveAuthentication no
PasswordAuthentication no
AllowUsers *@127.0.0.1
PermitRootLogin no
```

**UFW rules:**
```bash
sudo ufw allow 22/tcp
sudo ufw allow from 127.0.0.1 to any port 2222
sudo ufw enable
```

**Windows `~/.ssh/config`:**
```
Host bastion
    HostName 192.168.116.144
    User attacker
    IdentityFile C:\Users\USER\.ssh\id_ed25519

Host secure-zone
    HostName 127.0.0.1
    Port 2222
    User attacker
    IdentityFile C:\Users\USER\.ssh\id_ed25519
    ProxyJump bastion
```

### Verification
| Test | Result |
|------|--------|
| Direct SSH to port 2222 from outside | ✅ Connection refused |
| SSH via bastion with TOTP | ✅ Verification code prompted then connected |
| Auth log MFA acceptance | ✅ `Accepted google_authenticator for attacker` |
| Connection source | ✅ From `127.0.0.1` confirming bastion routing |

### Screenshots
![QR Code Setup](screenshots/TaskC-01-google-authenticator-qr-code-setup.png)
![PAM sshd config](screenshots/TaskC-02-pamd-sshd-google-authenticator-pam-time.png)
![sshd_config MFA](screenshots/TaskC-03-sshd-config-mfa-authenticationmethods.png)
![sshd_config_secure](screenshots/TaskC-04-sshd-config-secure-port-2222-allowusers.png)
![UFW rules](screenshots/TaskC-05-ufw-rules-port-22-allowed-2222-restricted.png)
![Port 2222 refused](screenshots/TaskC-06-port-2222-refused-externally-internal-success.png)
![Windows SSH config](screenshots/TaskC-07-windows-ssh-config-proxyjump-bastion.png)
![MFA login success](screenshots/TaskC-08-windows-ssh-secure-zone-mfa-totp-success.png)
![Auth log MFA](screenshots/TaskC-09-authlog-accepted-google-authenticator-127001.png)

---

## Task D — chroot Jail for Web Portal

### Why
A chroot jail changes the apparent root directory for a process.
From inside the jail the process believes the jail directory IS the entire filesystem.
`/data`, `/home`, `/etc/passwd` (real) — none of them exist from inside the jail.
Even a fully compromised web process cannot access what it cannot see.

### What I Did
- Created a complete fake filesystem at `/var/chroot/web/`
- Copied nginx binary and all shared libraries using `ldd`
- Copied minimal system files (`passwd`, `group`, `nsswitch.conf`)
- Created device files (`null`, `zero`, `urandom`)
- Fixed all permissions for the `www-data` user
- Created a systemd service using `RootDirectory=/var/chroot/web`
- Verified patient records are invisible from inside the jail

### Commands Used
```bash
# Create jail structure
sudo mkdir -p /var/chroot/web/{bin,lib,lib64,etc,tmp,dev}
sudo mkdir -p /var/chroot/web/var/log/nginx
sudo mkdir -p /var/chroot/web/var/lib/nginx/body
sudo mkdir -p /var/chroot/web/var/lib/nginx/proxy
sudo mkdir -p /var/chroot/web/var/www
sudo mkdir -p /var/chroot/web/run

# Copy nginx and all libraries
sudo cp /usr/sbin/nginx /var/chroot/web/bin/
for lib in $(ldd /usr/sbin/nginx | grep -o '/[^ ]*'); do
    sudo cp --parents "$lib" /var/chroot/web/ 2>/dev/null || true
done

# Copy system files
sudo cp /etc/passwd /etc/group /etc/nsswitch.conf /var/chroot/web/etc/

# Device files
sudo mknod -m 666 /var/chroot/web/dev/null    c 1 3
sudo mknod -m 666 /var/chroot/web/dev/zero    c 1 5
sudo mknod -m 666 /var/chroot/web/dev/urandom c 1 9

# Fix permissions
sudo chown -R www-data:www-data /var/chroot/web/var/log/nginx
sudo chown -R www-data:www-data /var/chroot/web/var/lib/nginx
sudo chown -R www-data:www-data /var/chroot/web/tmp
sudo chown -R www-data:www-data /var/chroot/web/run
```

### Systemd Service
```ini
[Unit]
Description=Nginx Web Portal (chroot isolated)
After=network.target

[Service]
Type=forking
RootDirectory=/var/chroot/web
User=www-data
Group=www-data
NoNewPrivileges=true
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_SETUID CAP_SETGID
PIDFile=/tmp/nginx.pid
ExecStart=/bin/nginx -c /etc/nginx/nginx.conf
ReadWritePaths=/var/log/nginx /var/lib/nginx /tmp /run

[Install]
WantedBy=multi-user.target
```

### Verification
```
sudo ls /proc/$(pgrep nginx | head -1)/root/
bin  dev  etc  lib  lib64  tmp  usr  var
← No /data  No /home  No real system files

sudo chroot /var/chroot/web /bin/sh -c 'ls /data'
No such file or directory  ← patient records invisible

curl http://localhost:8080
<h1>MedData Web Portal</h1>  ← web portal still works
```

| Test | Result |
|------|--------|
| nginx-jail.service status | ✅ active (running) |
| nginx process owner | ✅ www-data — not root |
| `/data` visible from jail | ✅ No such file or directory |
| `/bin/sh` in jail | ✅ Not present — hardened |
| Web portal responds | ✅ HTML content served on port 8080 |

### Screenshots
![Library copy](screenshots/TaskD-01-chroot-jail-library-copy-ldd-nginx.png)
![Service running](screenshots/TaskD-02-jail-permissions-nginx-service-active-running.png)
![Chroot verification](screenshots/TaskD-03-nginx-process-chroot-verification-curl-8080.png)

---

## Compliance Mapping

| Control | HIPAA Reference | GDPR Reference | Task |
|---------|----------------|----------------|------|
| Role-based access to PHI | 45 CFR § 164.312(a)(1) | Article 5(1)(f) | Task A |
| Audit controls and logging | 45 CFR § 164.312(b) | Article 32 | Task B |
| Time-based access restriction | 45 CFR § 164.308(a)(3) | Article 25 | Task B |
| Multi-factor authentication | 45 CFR § 164.312(d) | Article 32(1)(b) | Task C |
| Network segmentation | 45 CFR § 164.312(a)(1) | Article 25 | Task C |
| Process isolation | 45 CFR § 164.312(c)(2) | Article 32(1)(b) | Task D |

---

## Files Modified

| Task | File | What Changed |
|------|------|-------------|
| A | `/data/patient_records` | ACL entries via setfacl |
| B | `/etc/security/time.conf` | Time-of-day rules per group |
| B | `/etc/pam.d/sshd` | Added pam_time.so and google_authenticator |
| B | `/etc/pam.d/login` | Added pam_time.so |
| C | `/etc/ssh/sshd_config` | MFA AuthenticationMethods |
| C | `/etc/ssh/sshd_config_secure` | Port 2222 secure zone config |
| C | `~/.google_authenticator` | TOTP secret and scratch codes |
| C | UFW rules | Block 2222 externally, allow from 127.0.0.1 |
| D | `/var/chroot/web/` | Complete jail filesystem |
| D | `/etc/systemd/system/nginx-jail.service` | RootDirectory isolation |

---

## Key Lessons Learned

1. **ACL inheritance is not retroactive** — Default ACLs only apply to new files.
   Use `setfacl -R` to cover existing files.

2. **Every directory in a path needs execute permission** — Missing `x` on any
   intermediate directory blocks access even if the file's own ACL is correct.

3. **KbdInteractiveAuthentication controls TOTP prompts** — Set it to `yes` on
   the bastion for MFA, and `no` on the secure zone to prevent password prompts.

4. **chroot needs all dependencies** — Every `.so` library nginx needs must exist
   inside the jail. Use `ldd` to find them and `--parents` to preserve structure.

5. **nginx temp directories must be pre-created** — Without
   `/var/lib/nginx/body` and `/var/lib/nginx/proxy` inside the jail,
   nginx fails silently at startup with a read-only filesystem error.

6. **UFW rules persist across reboots — second sshd does not** — The port 2222
   sshd instance needs a proper systemd service to survive reboots.

---

*Lab completed on Ubuntu 24.04.2 LTS as part of an Identity and Access Management course.*
```

---