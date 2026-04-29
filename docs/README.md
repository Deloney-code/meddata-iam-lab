# MedData Research Hospital — IAM Lab Scenario 2
### Identity & Access Management | RBAC + ABAC | GDPR/HIPAA Compliance

![Ubuntu](https://img.shields.io/badge/Platform-Ubuntu_24.04-E95420?style=for-the-badge&logo=ubuntu)
![Security](https://img.shields.io/badge/Domain-Cybersecurity-red?style=for-the-badge)
![Compliance](https://img.shields.io/badge/Compliance-GDPR%20%2F%20HIPAA-blue?style=for-the-badge)
![Status](https://img.shields.io/badge/Lab_Status-Completed-brightgreen?style=for-the-badge)

---

## Table of Contents

- [Scenario Overview](#scenario-overview)
- [The Crisis — What Went Wrong](#the-crisis--what-went-wrong)
- [Why This Matters in Real Organizations](#why-this-matters-in-real-organizations)
- [Lab Architecture](#lab-architecture)
- [Task A — Linux ACLs](#task-a--linux-access-control-lists-acls)
- [Task B — PAM Time Restrictions](#task-b--pam-time-of-day-restrictions)
- [Task C — Bastion Host with MFA](#task-c--bastion-host-with-mfa)
- [Task D — chroot Jail](#task-d--chroot-jail-for-web-portal)
- [Verification Results](#verification-results)
- [Files Modified Summary](#files-modified-summary)
- [Key Lessons Learned](#key-lessons-learned)

---

## Scenario Overview

**Organization:** MedData Research Hospital  
**Platform:** Debian/Ubuntu servers  
**Compliance Framework:** GDPR (General Data Protection Regulation) + HIPAA (Health Insurance Portability and Accountability Act)  
**Role:** Cybersecurity Response Team  

MedData manages sensitive patient records on a network of Ubuntu servers segmented into three security zones:

| Zone | Purpose | Risk Level |
|------|---------|-----------|
| Public | Web portal — patient appointment booking | Medium |
| Internal | Staff workstations and internal tools | High |
| Secure | Patient records database — PHI storage | Critical |

---

## The Crisis — What Went Wrong

An internal audit uncovered **four critical violations** that put patient data at risk and exposed the hospital to regulatory penalties:

### Violation 1 — Overprivileged Staff Access
The `staff` group had broad **read access** to `/data/patient_records`. Every member of the staff group — from receptionists to cleaners — could read confidential patient medical records. This directly violates the **HIPAA Minimum Necessary Rule**, which states that access to Protected Health Information (PHI) must be limited to only what is needed for each role.

### Violation 2 — Shared Credentials Across Security Zones
System administrators were using the **same SSH credentials** to log into both the public web server and the secure patient records database. A single compromised login gave an attacker a direct path from the public internet to the most sensitive data in the hospital.

### Violation 3 — No Time-of-Day Access Controls
There were **no restrictions on when** employees could access the system. Staff could log in and query patient records at 3:00 AM from home with no oversight, no alerting, and no audit trail. HIPAA requires audit controls that track and limit access to PHI.

### Violation 4 — Web Process Had Full Filesystem Access
The web portal process ran with access to the **entire server filesystem**. If an attacker exploited a vulnerability in the web application (SQL injection, RCE, etc.), they would immediately have access to patient records stored elsewhere on the same server.

---

## Why This Matters in Real Organizations

### HIPAA Implications
- **45 CFR § 164.312(a)(1)** — Access Control: Implement technical policies to allow only authorized persons to access ePHI
- **45 CFR § 164.312(b)** — Audit Controls: Hardware/software activity must be recorded and examined
- **45 CFR § 164.308(a)(3)** — Workforce Authorization: Access to PHI must be role-appropriate
- **Penalties:** HIPAA violations range from $100 to $50,000 per violation, up to $1.9M per year per violation category

### GDPR Implications
- **Article 5(1)(f)** — Integrity and Confidentiality: Personal data must be protected against unauthorized access
- **Article 25** — Data Protection by Design: Security must be built into systems, not added later
- **Article 32** — Security of Processing: Appropriate technical measures must be implemented
- **Penalties:** Up to €20 million or 4% of global annual turnover — whichever is higher

### Real-World Incidents This Lab Addresses
- **2020 Universal Health Services Ransomware Attack** — $67M loss partly due to insufficient network segmentation
- **2023 HCA Healthcare Breach** — 11 million patient records exposed due to overprivileged access
- **2022 CommonSpirit Health Attack** — Insufficient access controls led to weeks of system downtime

### The Four Security Principles Applied
```
Principle of Least Privilege  →  Task A (ACLs) + Task B (PAM)
Defense in Depth              →  Task C (Bastion) + Task D (chroot)
Zero Trust Architecture       →  Task C (No direct zone access, MFA required)
Fail-Safe Defaults            →  Task A (Explicit deny for staff group)
```

---

## Lab Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Lab Environment                           │
│                                                             │
│   Windows Host (192.168.116.1)  ←── External tester        │
│          │                                                  │
│          │  SSH key + TOTP (MFA)                           │
│          ▼                                                  │
│   ┌─────────────────────────────────────────────────┐      │
│   │         Ubuntu 24.04  (192.168.116.144)          │      │
│   │                                                  │      │
│   │  ┌──────────────┐    ┌──────────────────────┐   │      │
│   │  │  BASTION     │    │   SECURE ZONE        │   │      │
│   │  │  Port 22     │───▶│   Port 2222          │   │      │
│   │  │  MFA enabled │    │   Key-only, internal │   │      │
│   │  └──────────────┘    └──────────────────────┘   │      │
│   │                                                  │      │
│   │  ┌──────────────┐    ┌──────────────────────┐   │      │
│   │  │  WEB PORTAL  │    │  PATIENT RECORDS     │   │      │
│   │  │  chroot jail │    │  /data/patient_      │   │      │
│   │  │  Port 8080   │    │  records (ACL)       │   │      │
│   │  └──────────────┘    └──────────────────────┘   │      │
│   └─────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Users and Groups Created

| User | Group | Role | Access Level |
|------|-------|------|-------------|
| `audit_user` | — | Compliance auditor | Read-only on patient records |
| `staff_user1` | `staff` | Hospital staff | Blocked from patient records |
| `doctor1` | `doctors` | Medical staff | Full access to patient records |
| `attacker` | `sudo`, `bastion_users` | Admin | Full access via bastion + MFA |

---

## Task A — Linux Access Control Lists (ACLs)

### Problem
Standard Linux UGO (User-Group-Others) permissions could not handle the granularity required. The `audit_user` needed read-only access to patient records for compliance purposes, but adding them to the `doctors` group would grant write access too. The `staff` group needed to be explicitly blocked without removing them from the server.

### Why ACLs Are the Right Solution
Linux ACLs extend the standard permission model by allowing **per-user and per-group rules** independent of file ownership. This is essential for HIPAA compliance where the same file may need different access levels for different roles simultaneously.

### Implementation

```bash
# Install ACL tools
sudo apt install -y acl

# Create directory structure
sudo mkdir -p /data/patient_records/sensitive

# Set base ownership — doctors group owns the directory
sudo chown root:doctors /data/patient_records
sudo chmod 750 /data/patient_records

# Grant audit_user READ-ONLY via ACL (no group change)
sudo setfacl -m u:audit_user:r-x /data/patient_records
sudo setfacl -m u:audit_user:r-x /data/patient_records/sensitive
sudo setfacl -R -m u:audit_user:r-- /data/patient_records/sensitive

# Grant doctors group FULL access
sudo setfacl -m g:doctors:rwx /data/patient_records

# EXPLICITLY DENY staff group
sudo setfacl -m g:staff:--- /data/patient_records

# Set DEFAULT ACL so new files inherit permissions
sudo setfacl -d -m u:audit_user:r-- /data/patient_records
sudo setfacl -d -m g:staff:--- /data/patient_records

# Apply recursively to all existing files
sudo setfacl -R -m u:audit_user:r-- /data/patient_records/

# Verify
getfacl /data/patient_records
```

### Resulting ACL Configuration

```
# file: data/patient_records
# owner: root
# group: doctors
user::rwx
user:audit_user:r-x          ← audit_user: read only, no write
group::r-x
group:staff:---              ← staff: completely blocked
group:doctors:rwx            ← doctors: full access
mask::rwx
other::---
default:user::rwx
default:user:audit_user:r--
default:group::r-x
default:group:staff:---
default:mask::r-x
default:other::---
```

### Key Technical Note
> **Important lesson learned during implementation:** Default ACLs only apply to **newly created files**. Files that existed before the ACL was set require the `-R` (recursive) flag to retroactively apply permissions. Additionally, **every directory in the path** must have the execute (`x`) bit set for the target user — not just the final directory. Both `/data/patient_records` AND `/data/patient_records/sensitive` required explicit ACL entries for `audit_user`.

### Verification Results

| Test | Command | Expected | Result |
|------|---------|----------|--------|
| audit_user reads file | `sudo -u audit_user cat /data/patient_records/sensitive/record1` | `test data` | ✅ PASS |
| audit_user writes file | `sudo -u audit_user bash -c 'echo hack > record1'` | `Permission denied` | ✅ PASS |
| staff_user1 lists dir | `sudo -u staff_user1 ls /data/patient_records` | `Permission denied` | ✅ PASS |
| doctor1 lists dir | `sudo -u doctor1 ls /data/patient_records` | Shows contents | ✅ PASS |
| doctor1 creates file | `sudo -u doctor1 bash -c 'echo note > doctor_note.txt'` | Success | ✅ PASS |

---

## Task B — PAM Time-of-Day Restrictions

### Problem
No time-based restrictions existed on system access. An employee could authenticate to the patient records system at 3:00 AM from home with no oversight. Under HIPAA's audit control requirements, access outside business hours — especially from off-site locations — must be restricted and logged.

### Why PAM Is the Right Solution
PAM (Pluggable Authentication Modules) enforces access policies **at the operating system level**, before any application sees the login attempt. This means the restriction applies to ALL services (SSH, console, FTP) simultaneously through a single configuration. It cannot be bypassed by targeting a different application layer.

### Configuration Files Modified

**`/etc/security/time.conf`** — Defines the time rules:
```
# Allow staff SSH only Mon-Fri 0800-2000
sshd;*;%staff;Wk0800-2000

# Allow doctors SSH Mon-Fri 0700-2100
sshd;*;%doctors;Wk0700-2100

# Allow audit_user SSH Mon-Fri business hours only
sshd;*;audit_user;Wk0800-1800

# Temporary test block for verification
sshd;*;staff_user1;!Wk1000-1100

# Block ALL console logins midnight-6am for non-root
login;*;!root;!Al0000-0600
```

**`/etc/pam.d/sshd`** — Loads the time module for SSH:
```
auth required pam_google_authenticator.so nullok
@include common-auth
account    required    pam_time.so         ← added this line
```

**`/etc/pam.d/login`** — Loads the time module for console logins:
```
@include common-auth
account    required    pam_time.so         ← added this line
```

### Verification Results

The auth log confirmed PAM enforcement:

```
sshd[1900]: fatal: Access denied for user staff_user1
            by PAM account configuration [preauth]
```

| Test | Scenario | Result |
|------|----------|--------|
| Login during allowed hours | `ssh staff_user1@localhost` (within Wk0800-2000) | ✅ Allowed |
| Login during blocked hours | `ssh staff_user1@localhost` (during !Wk1000-1100 test rule) | ✅ Denied |
| Auth log evidence | `grep pam /var/log/auth.log` | ✅ Shows PAM account denial |

---

## Task C — Bastion Host with MFA

### Problem
System administrators used the same credentials for the public web server and the secure patient records database. This single-factor, shared-credential model meant one stolen password compromised everything. There was no separation between the public-facing zone and the secure zone containing PHI.

### Why a Bastion Host + MFA Is the Right Solution
A **Bastion Host** (Jump Server) enforces a single, hardened entry point to the secure zone. Combined with **Multi-Factor Authentication (TOTP)**, it ensures:
- Something you **have** (SSH private key)
- Something you **know/possess** (time-based one-time password from phone)

Even if an attacker steals the private key, they still cannot access the secure zone without the physical TOTP device.

### Architecture

```
External Client (Windows 192.168.116.1)
         │
         │  Step 1: SSH key authentication
         │  Step 2: Google Authenticator TOTP code
         ▼
  [BASTION HOST — port 22]
  AuthenticationMethods publickey,keyboard-interactive
  KbdInteractiveAuthentication yes
  pam_google_authenticator.so required
         │
         │  ProxyJump (internal only)
         │  Key-only, no MFA needed for internal hop
         ▼
  [SECURE ZONE — port 2222]
  AllowUsers *@127.0.0.1  (only from bastion)
  UFW: DENY 2222 from anywhere except 127.0.0.1
```

### Implementation

**Step 1 — Install Google Authenticator:**
```bash
sudo apt install -y libpam-google-authenticator
google-authenticator
# Scan QR code with Authenticator app
```

**Step 2 — Configure PAM for MFA (`/etc/pam.d/sshd`):**
```
auth required pam_google_authenticator.so nullok
@include common-auth
account    required    pam_time.so
```

**Step 3 — Configure Bastion sshd (`/etc/ssh/sshd_config`):**
```
AuthenticationMethods publickey,keyboard-interactive
KbdInteractiveAuthentication yes
PasswordAuthentication no
AllowGroups bastion_users sudo
PermitRootLogin no
LogLevel VERBOSE
```

**Step 4 — Configure Secure Zone (`/etc/ssh/sshd_config_secure`):**
```
Port 2222
AuthenticationMethods publickey
KbdInteractiveAuthentication no
PasswordAuthentication no
AllowGroups bastion_users sudo
AllowUsers *@127.0.0.1
PermitRootLogin no
LogLevel VERBOSE
```

**Step 5 — Start Secure Zone sshd and set UFW rules:**
```bash
sudo /usr/sbin/sshd -f /etc/ssh/sshd_config_secure

sudo ufw allow 22/tcp
sudo ufw allow from 127.0.0.1 to any port 2222
sudo ufw enable
```

**Step 6 — Windows SSH config (`~/.ssh/config`):**
```
# Bastion — requires key + MFA
Host bastion
    HostName 192.168.116.144
    User attacker
    IdentityFile C:\Users\USER\.ssh\id_ed25519

# Secure zone — only reachable through bastion
Host secure-zone
    HostName 127.0.0.1
    Port 2222
    User attacker
    IdentityFile C:\Users\USER\.ssh\id_ed25519
    ProxyJump bastion
```

### Verification Results

| Test | Command | Expected | Result |
|------|---------|----------|--------|
| Direct external SSH to port 2222 | `ssh -p 2222 attacker@192.168.116.144` | Connection refused | ✅ PASS |
| SSH via bastion with MFA | `ssh secure-zone` from Windows | Prompts for TOTP, then connects | ✅ PASS |
| Auth log — MFA accepted | `grep Accepted /var/log/auth.log` | Shows `Accepted google_authenticator for attacker` | ✅ PASS |
| Auth log — source verification | `sudo last \| head -5` | Shows connections from `127.0.0.1` (bastion) | ✅ PASS |

**Auth log evidence of successful MFA:**
```
sshd(pam_google_authenticator): Accepted google_authenticator for attacker
sshd: Accepted keyboard-interactive/pam for attacker from 192.168.116.1 port 63608 ssh2
```

---

## Task D — chroot Jail for Web Portal

### Problem
The nginx web portal process ran with full access to the host filesystem. A successful web application attack (SQL injection, remote code execution, path traversal) would give an attacker immediate access to `/data/patient_records`. The web portal had no business accessing patient data, yet it technically could.

### Why chroot Is the Right Solution
A **chroot jail** changes the apparent root directory (`/`) for a process. From inside the jail, the process believes the jail directory IS the entire filesystem. `/data`, `/home`, `/etc/passwd` (real), and all other sensitive paths simply **do not exist** from the process's perspective. Even a fully compromised web process cannot access what it cannot see.

Combined with **systemd hardening directives** (`NoNewPrivileges`, `CapabilityBoundingSet`), this implements defense-in-depth at the process level.

### Implementation

```bash
# Create jail directory structure
sudo mkdir -p /var/chroot/web/{bin,lib,lib64,etc,tmp,dev}
sudo mkdir -p /var/chroot/web/var/{log/nginx,lib/nginx,www}

# Copy nginx binary
sudo cp /usr/sbin/nginx /var/chroot/web/bin/

# Copy all required shared libraries
for lib in $(ldd /usr/sbin/nginx | grep -o '/[^ ]*'); do
    sudo cp --parents "$lib" /var/chroot/web/ 2>/dev/null || true
done

# Copy essential system files
sudo cp /etc/passwd /etc/group /etc/nsswitch.conf /var/chroot/web/etc/

# Create device files
sudo mknod -m 666 /var/chroot/web/dev/null    c 1 3
sudo mknod -m 666 /var/chroot/web/dev/zero    c 1 5
sudo mknod -m 666 /var/chroot/web/dev/urandom c 1 9

# Fix permissions for nginx process
sudo chown -R www-data:www-data /var/chroot/web/var/log/nginx
sudo chown -R www-data:www-data /var/chroot/web/var/lib/nginx
sudo chown -R www-data:www-data /var/chroot/web/tmp
sudo chmod 755 /var/chroot/web/var/log/nginx
```

**Systemd service (`/etc/systemd/system/nginx-jail.service`):**
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
PrivateTmp=false
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_SETUID CAP_SETGID
ExecStart=/bin/nginx -c /etc/nginx/nginx.conf -g 'daemon on;'
ReadWritePaths=/var/log/nginx /var/lib/nginx /tmp

[Install]
WantedBy=multi-user.target
```

### Verification Results

```bash
# Service running
sudo systemctl status nginx-jail.service
# Active: active (running) since Tue 2026-04-21 15:03:01 UTC

# Process filesystem view
sudo ls /proc/$(pgrep nginx | head -1)/root/
# bin  dev  etc  lib  lib64  proc  root  run  sys  tmp  usr  var
# NOTE: No /data, no /home, no real /etc

# Chroot escape attempts all FAILED
sudo chroot /var/chroot/web /bin/sh -c "ls /"
# chroot: failed to run command '/bin/sh': No such file or directory

sudo chroot /var/chroot/web /bin/sh -c "ls /data"
# chroot: failed to run command '/bin/sh': No such file or directory

# Web portal serving correctly
curl http://localhost:8080
# <h1>MedData Web Portal</h1>
```

| Test | Expected | Result |
|------|----------|--------|
| Service status | active (running) | ✅ PASS |
| nginx process owner | www-data (not root) | ✅ PASS |
| `/data` visible from jail | No such file or directory | ✅ PASS |
| `/bin/sh` available in jail | Not present (hardened) | ✅ PASS |
| Web portal responds | HTML content served | ✅ PASS |

---

## Verification Results

### Complete Lab Summary

| Task | Violation Fixed | Tool Used | Proof of Success |
|------|----------------|-----------|-----------------|
| **A — ACLs** | Staff group had broad read access to all patient records | `setfacl` / `getfacl` | `staff_user1 ls` → Permission denied |
| **B — PAM** | No time-of-day login restrictions | `pam_time.so` / `time.conf` | auth.log: `Access denied by PAM account configuration` |
| **C — Bastion+MFA** | Same credentials for public and secure zones | OpenSSH ProxyJump + Google Authenticator | Direct port 2222 → Connection refused; via bastion → TOTP prompt → success |
| **D — chroot** | Web process had full filesystem access | chroot + systemd `RootDirectory` | `/data` not visible from jail; web portal still serves content |

---

## Files Modified Summary

| Task | File | Change Made |
|------|------|-------------|
| A | `/data/patient_records` | ACL entries via `setfacl` |
| B | `/etc/security/time.conf` | Added time-of-day rules per group |
| B | `/etc/pam.d/sshd` | Added `account required pam_time.so` + google authenticator |
| B | `/etc/pam.d/login` | Added `account required pam_time.so` |
| C | `/etc/ssh/sshd_config` | `AuthenticationMethods publickey,keyboard-interactive` + MFA |
| C | `/etc/ssh/sshd_config_secure` | Port 2222, key-only, `AllowUsers *@127.0.0.1` |
| C | `~/.google_authenticator` | TOTP secret and scratch codes |
| C | UFW rules | Allow 22/tcp everywhere; allow 2222 from 127.0.0.1 only |
| C | `~/.ssh/config` (Windows) | ProxyJump bastion configuration |
| D | `/var/chroot/web/` | Complete jail filesystem tree |
| D | `/etc/systemd/system/nginx-jail.service` | `RootDirectory` + hardening directives |

---

## Key Lessons Learned

### 1. ACL Inheritance Does Not Apply Retroactively
Default ACLs (`setfacl -d`) only affect **new files created after the ACL is set**. Existing files require `setfacl -R` to apply permissions recursively. In a production environment, always run both commands when securing an existing directory tree.

### 2. Every Directory in a Path Needs Execute Permission
For a user to access `/data/patient_records/sensitive/record1`, they need execute (`x`) permission on **every directory** in that path — not just the final one. Missing execute on any intermediate directory results in "Permission denied" even if the file's own ACL is correct.

### 3. PAM Stacks Are Order-Dependent
The order of lines in `/etc/pam.d/sshd` matters. `pam_google_authenticator.so` must be the **first** `auth` line so it prompts for TOTP before any other authentication check. Placing it after `@include common-auth` changes the authentication flow.

### 4. chroot Requires All Dependencies
A chroot jail is only functional if **every shared library** the process needs is present inside the jail. Using `ldd` to enumerate dependencies and copying them with `--parents` ensures the correct directory structure is preserved. A missing `.so` file causes the process to fail silently at runtime.

### 5. KbdInteractiveAuthentication Is the Hidden Gate
Setting `PasswordAuthentication no` alone does **not** fully disable password-based access. `KbdInteractiveAuthentication yes` must be set deliberately for TOTP to work, while `KbdInteractiveAuthentication no` on the secure zone prevents password prompts from appearing where they should not.

### 6. UFW Rules Persist Across Reboots — sshd Instances Do Not
UFW rules survive reboots automatically. The second `sshd` instance started with `sudo /usr/sbin/sshd -f /etc/ssh/sshd_config_secure` does **not** survive a reboot. In production, create a proper systemd service for the secure zone sshd instance to ensure it starts automatically.

---

## Compliance Mapping

| Control | HIPAA Reference | GDPR Reference | Implemented By |
|---------|----------------|----------------|---------------|
| Role-based access to PHI | 45 CFR § 164.312(a)(1) | Article 5(1)(f) | Task A — ACLs |
| Audit controls and access logging | 45 CFR § 164.312(b) | Article 32 | Task B — PAM + auth.log |
| Time-based access restriction | 45 CFR § 164.308(a)(3) | Article 25 | Task B — pam_time |
| Multi-factor authentication | 45 CFR § 164.312(d) | Article 32(1)(b) | Task C — Google Authenticator |
| Network segmentation | 45 CFR § 164.312(a)(1) | Article 25 | Task C — Bastion + UFW |
| Process isolation | 45 CFR § 164.312(c)(2) | Article 32(1)(b) | Task D — chroot jail |

---

## How to Reproduce This Lab

### Prerequisites
- Ubuntu 24.04 (VM or bare metal)
- `sudo` privileges
- Google Authenticator app on a mobile device
- SSH key pair

---

*Lab completed as part of an Identity & Access Management course.*  
*All configurations were implemented and verified on Ubuntu 24.04.2 LTS.*
