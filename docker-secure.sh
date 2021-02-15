#!/bin/bash
clear

set -eux
SERVER_PUBLIC_IP=`hostname -I|cut -d" " -f 1`
STR=4096
if [ "$#" -gt 0 ]; then
  export HOST="$1"
  export USERNAME="$2"
else
  echo "ERROR: You must specify the docker FQDN as the first arguement, and  USERNAME for being able to execute inctructions to the Docker Daemon! <="
  exit 1
fi

if [ "$USER" == "root" ]; then
  echo "WARNING: You're running this script as root, therefore root will be configured to talk to docker."
  echo "If you want to have other users query docker too, you'll need to symlink .docker to $USERNAME/.docker"
fi

echo "Using Hostname: $HOST  You MUST connect to docker using this host!"

echo "Ensuring config directory exists..."
mkdir -p "/root/.docker"
cd /root/.docker

echo "Verifying ca.srl"
if [ ! -f "ca.src" ]; then
  echo "  Creating ca.srl"
  echo 01 > ca.srl
fi

echo "Generating CA key"
openssl genrsa -out ca-key.pem $STR

echo "Generating CA certificate"
openssl req -new -x509 -days 3650 -key ca-key.pem -subj "/CN=$HOST" -out ca.pem

echo "Generating server key"
openssl genrsa -out server-key.pem $STR

echo "Generating server CSR"
openssl req -subj "/CN=$HOST" -new -key server-key.pem -out server.csr

echo "Specified IP addresses to allow connections FROM, and extended key usage"
echo "subjectAltName = DNS:$HOST,IP:${SERVER_PUBLIC_IP},IP:127.0.0.1" >> /root/.docker/extfile.cnf
echo "extendedKeyUsage = serverAuth" >> /root/.docker/extfile.cnf


echo "Signing public key with our CA"
openssl x509 -req -days 3650 -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile /root/.docker/extfile.cnf

echo "Generating client key and certificate signing request"
openssl genrsa -out key.pem $STR

echo "Generating client CSR"
openssl req -subj '/CN=client' -new -key key.pem -out client.csr

echo "Generating client authentication with create a new extensions config file"
echo extendedKeyUsage = clientAuth > /root/.docker/extfile-client.cnf

echo "Signing client CSR with CA"
openssl x509 -req -days 3650 -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -extfile /root/.docker/extfile-client.cnf

echo "Remove not needed files"
rm -v client.csr server.csr extfile.cnf /root/.docker/extfile-client.cnf

echo "Setting appropriate permissions.."
chmod -v 0400 ca-key.pem key.pem server-key.pem
chmod -v 0444 ca.pem server-cert.pem cert.pem

echo "Configuring Docker to use the ssl certificates..."

DOCKER_DEAMON_OPTS='{
	"exec-opts": ["native.cgroupdriver=systemd"],
	"log-driver": "json-file",
	"log-opts": {
		"max-size": "100m"
	},
	"storage-driver": "overlay2",
	"icc": false,
	"live-restore": true,
	"userland-proxy": false,
	"default-ulimit": "nofile=50:100"
}'

DOCKER_SYSTEMD_OPTS="[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H tcp://${SERVER_PUBLIC_IP}:2376 -H unix:///var/run/docker.sock --tlsverify --tlscacert /root/.docker/ca.pem --tlscert /root/.docker/server-cert.pem --tlskey /root/.docker/server-key.pem"

if [ ! -f /etc/docker/daemon.json ]; then
echo "Creating /etc/docker/daemon.json"
cat > /etc/docker/daemon.json <<EOF
$DOCKER_DEAMON_OPTS
EOF

echo "Creating Docker.Service.D Directory"
mkdir -p /etc/systemd/system/docker.service.d
echo "  Applying certificates to docker service"
cat > /etc/systemd/system/docker.service.d/tls.conf <<EOF
$DOCKER_SYSTEMD_OPTS
EOF
else
echo "The file /etc/docker/daemon.json already exists. It will be updated"
rm /etc/docker/daemon.json
echo "  Creating /etc/docker/daemon.json"
cat > /etc/docker/daemon.json <<EOF
$DOCKER_DEAMON_OPTS
EOF
sudo chmod 644 -R /etc/docker
fi

echo "Copying certificates to the $USERNAME directory"
mkdir -p /home/$USERNAME
mkdir -p /home/$USERNAME/.docker
cp -v /root/.docker/{ca,cert,key}.pem /home/$USERNAME/.docker
echo "Adjusting $USERNAME permissions to control Docker"
chown root:$USERNAME /home/$USERNAME/.docker/ca.pem
chown root:$USERNAME /home/$USERNAME/.docker/key.pem
chmod 440 /home/$USERNAME/.docker/key.pem


echo "Adding Environment Variables to Profile.D"
if [ -d "/etc/profile.d" ]; then
echo "  Profile.D Folder exists, creating profile.d/docker"
sudo sh -c "echo '#!/bin/bash
export DOCKER_CERT_PATH=/home/${USERNAME}/.docker
export DOCKER_HOST=tcp://${HOST}:2376
export DOCKER_TLS_VERIFY=1
export COMPOSE_TLS_VERSION=TLSv1_2' > /etc/profile.d/docker.sh"
sudo chmod +x /etc/profile.d/docker.sh
source /etc/profile.d/docker.sh
else
mkdir /etc/profile.d
echo "  Creating profile.d/docker"
sudo sh -c "echo '#!/bin/bash
export DOCKER_CERT_PATH=/home/${USERNAME}/.docker
export DOCKER_HOST=tcp://${HOST}:2376
export DOCKER_TLS_VERIFY=1
export COMPOSE_TLS_VERSION=TLSv1_2' > /etc/profile.d/docker.sh"
sudo chmod +x /etc/profile.d/docker.sh
source /etc/profile.d/docker.sh
fi

echo "Exporting Environment Variables..."
export DOCKER_CERT_PATH=/home/${USERNAME}/.docker
export DOCKER_HOST=tcp://${HOST}:2376
export DOCKER_TLS_VERIFY=1
export COMPOSE_TLS_VERSION=TLSv1_2

echo "All Done! You just need to restart docker for the changes to take effect"
echo "Reloading Docker Deamon"
sudo systemctl daemon-reload
sudo sleep 3s
echo "Restarting Docker Service"
sudo systemctl restart docker
echo " Installation finished"