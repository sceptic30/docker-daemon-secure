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
You don't need to run ```usermod -aG docker {user}``` to add your user to the docker group after you set this up, because your user will be already be eligable to control the docker daemon via the certificates.

# Knows Bug
Currently, is not possible to use docker-compose with secure daemon because of a bug.
Please see this issue https://github.com/docker/compose/issues/7675
