# rpcenum
RPC enumeration script for Active Directory environments via `rpcclient`.
> **Original credits:** [Marcelo Vázquez (S4vitar)](https://github.com/s4vitar)  
> This repository contains an updated and modified version of the original script.
---
## What does it do?
Automates the enumeration of a Windows domain through the RPC protocol (port 139), allowing you to extract:
- **DUsers** — Domain users
- **DUsersInfo** — Domain users with description
- **DAUsers** — Users in the Domain Admins group
- **DGroups** — Domain groups
- **All** — All of the above modes in sequence
---
## Changes from the original
- Support for **authentication with credentials** (username and password), in addition to null session
- **Interactive mode**: if no flags are passed, the script prompts for data step by step
- New flags `-u` (username) and `-p` (password)
- Centralized `rpcclient_cmd()` wrapper to handle null session vs. authenticated session
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
The script will prompt you for the IP, username, password, and enumeration mode.
### Flag mode
```bash
# Null session
sudo rpcenum -i 192.168.1.10 -e All
# With credentials
sudo rpcenum -i 192.168.1.10 -e All -u Administrator -p 'P@ssw0rd'
# Show help
sudo rpcenum -h
```
### Available flags
| Flag | Description |
|------|-------------|
| `-i` | Target IP |
| `-e` | Enumeration mode (`DUsers`, `DUsersInfo`, `DAUsers`, `DGroups`, `All`) |
| `-u` | Username (optional, default: null session) |
| `-p` | Password (optional) |
| `-h` | Help panel |
---
## Requirements
- Kali Linux (or any distro with `rpcclient` and `nmap`)
- Must be run as **root**
- Port **139** open on the target
---
## Disclaimer
This script is intended for use in controlled environments with explicit authorization.  
Unauthorized use against third-party systems is illegal.
