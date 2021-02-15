# Secure Docker Daemon
Secure Docker Daemon with SSL Certificates
# Usage
You must be root, or run this script with sudo privileges.
The script accepts 2 arguments:
1)A domain name. This is represented by the variable $HOST within the script.
2)A username which is the user that you usually ssh to the server.This is represented by the variable $USERNAME within the script.

```bash
git clone https://github.com/sceptic30/docker-daemon-secure.git
cd docker-daemon-secure
sudo ./docker-daemon-secure example.com your_username
```
