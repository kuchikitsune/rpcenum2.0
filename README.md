# rpcenum
RPC enumeration script for Active Directory environments via `rpcclient`.

> **Original credits:** [Marcelo Vázquez (S4vitar)](https://github.com/s4vitar)  
> This repository contains an updated and modified version of the original script.

---

## What does it do?
Automates the enumeration of a Windows domain through the RPC protocol (SMB ports 445/139), allowing you to extract:

- **DUsers** — Domain users
- **DUsersInfo** — Domain users with description
- **DAUsers** — Users in the Domain Admins group
- **DAUsersInfo** — Domain Admins with description
- **DGroups** — Domain groups
- **PassPol** — Domain password policy (`getdompwinfo`)
- **DomInfo** — General domain info (`querydominfo`)
- **All** — All of the above modes in sequence

Results can optionally be exported to a directory with the `-o` flag.

---

## Changes from the original
- Support for **authentication with credentials** (username and password), in addition to null session
- **Pass-the-Hash** support via `-H` (NT hash, requires `-u`)
- **Result export** with `-o <dir>` — each mode writes its output to a file (`.txt` / `.csv`)
- New enumeration modes: **PassPol** (password policy) and **DomInfo** (domain info)
- **Interactive mode**: if no flags are passed, the script prompts for data step by step (now also asks about hash and output directory)
- Flags `-u` (username), `-p` (password), `-H` (NT hash), `-o` (output directory)
- Centralized `rpcclient_cmd()` wrapper to handle null session / authenticated / Pass-the-Hash
- **Port check on 445 and 139** (modern SMB + legacy), with reliable status capture
- **Secure temporary files** via `mktemp` (unique per run, no collisions between instances)
- **Dependency check** at startup (`rpcclient`, `nmap`, `awk`, `column`, `sed`, `grep`)
- Safer handling of usernames via `mapfile` (avoids word-splitting issues)
- Removed dead `rpc_auth()` function
- Improved temporary file cleanup with `rm -f`
- `trap ctrl_c INT` moved to global scope
- More descriptive error messages when access is denied

---

## Installation
```bash
chmod +x rpcenum.sh
sudo cp rpcenum.sh /usr/local/bin/rpcenum
```

---

## Usage

### Interactive mode (no flags)
```bash
sudo rpcenum
```
The script will prompt you for the IP, username, password (or NT hash), output directory, and enumeration mode.

### Flag mode
```bash
# Null session
sudo rpcenum -i 192.168.1.10 -e All

# With credentials
sudo rpcenum -i 192.168.1.10 -e All -u Administrator -p 'P@ssw0rd'

# Pass-the-Hash (NT hash)
sudo rpcenum -i 192.168.1.10 -e DUsers -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0

# Export results to a directory
sudo rpcenum -i 192.168.1.10 -e All -o loot

# Show help
sudo rpcenum -h
```

### Available flags
| Flag | Description |
|------|-------------|
| `-i` | Target IP |
| `-e` | Enumeration mode (`DUsers`, `DUsersInfo`, `DAUsers`, `DAUsersInfo`, `DGroups`, `PassPol`, `DomInfo`, `All`) |
| `-u` | Username (optional, default: null session) |
| `-p` | Password (optional) |
| `-H` | NT hash for Pass-the-Hash (optional, requires `-u`) |
| `-o` | Output directory — exports results to files (optional) |
| `-h` | Help panel |

---

## Output files
When `-o <dir>` is set, results are written as:

| Mode | File |
|------|------|
| DUsers | `domain_users.txt` |
| DUsersInfo | `domain_users_info.csv` |
| DAUsers | `domain_admins.txt` |
| DAUsersInfo | `domain_admins_info.csv` |
| DGroups | `domain_groups.csv` |
| PassPol | `password_policy.txt` |
| DomInfo | `domain_info.txt` |

---

## Requirements
- `rpcclient` (Samba suite)
- `nmap`
- Standard core utils: `awk`, `column`, `sed`, `grep`
- Your fav linux distro
- Must be run as **root**

---

## Disclaimer
This script is intended for use in controlled environments with explicit authorization.  
Unauthorized use against third-party systems is illegal.
