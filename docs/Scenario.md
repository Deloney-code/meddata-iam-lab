# Scenario 2: The "MedData" Research Hospital

## Context
Strict data silos and regulatory compliance (GDPR/HIPAA).

## The Organization
"MedData" manages sensitive patient records on a network of Debian servers.
The network is segmented into three zones:
- Public (Web Portal)
- Internal (Staff)
- Secure (Patient Records)

## The IAM Crisis
An internal audit found that the "Staff" group has broad read-access to the
`/data/patient_records` directory. Additionally, the system administrators are
using the same credentials to log into the public web server as they do for the
secure database. There is no "Time-of-Day" restriction, meaning employees can
access records at 3:00 AM from home without oversight.

## The  Challenge
As the Cybersecurity Response Team, you must enforce strict
Role-Based Access Control (RBAC) and Attribute-Based Access Control (ABAC).

- **Task A:** Implement Linux ACLs (Access Control Lists) to provide granular
  permissions that standard UGO (User, Group, Others) bits cannot handle
  (e.g., giving a specific "Audit" user read access without changing group ownership).

- **Task B:** Set up PAM (Pluggable Authentication Modules) to enforce
  "Time-of-Day" login restrictions using pam_time.conf.

- **Task C:** Secure the networking layer by implementing a Jump Server
  (Bastion Host). No one should be able to SSH directly into the "Secure" zone;
  they must first authenticate through the Bastion with Multi-Factor
  Authentication (MFA).

- **Task D:** Use chroot jails or Linux Namespaces to isolate the Web Portal
  process, ensuring that if the web service is compromised, the attacker cannot
  see the rest of the file system.

## Instructions
1. **Analyze:** Identify the specific Linux configuration files involved
   (e.g., /etc/ssh/sshd_config, /etc/security/limits.conf, /etc/sudoers).

2. **Collaborate:** Divide roles — one student acts as the "Network Lead,"
   one as the "Systems Admin," and one as the "Security Auditor."

3. **Execute:** Write the specific commands or policy lines required to fix
   the issues.

4. **Verify:** How would you test that your solution works?
   (e.g., attempting to log in as a Junior Dev and trying to run a
   restricted command).