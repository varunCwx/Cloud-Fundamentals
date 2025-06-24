# modules/compute/startup.tpl.sh
#!/bin/bash
set -xe
exec > /var/log/startupscript.log 2>&1

sudo apt-get update
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release \
  curl

curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo systemctl start docker

echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
  http://packages.cloud.google.com/apt cloud-sdk main" \
  > /etc/apt/sources.list.d/google-cloud-sdk.list

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

apt-get update
apt-get install -y google-cloud-sdk

gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

BACKEND_IMAGE="${backend_image}"
DB_PRIVATE_IP="${db_private_ip}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
DB_NAME="${db_name}"

docker pull "$BACKEND_IMAGE"
docker run -d \
  --name backend-container \
  -p 5000:5000 \
  -e DB_HOST="$DB_PRIVATE_IP" \
  -e DB_USER="$DB_USER" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e DB_NAME="$DB_NAME" \
  "$BACKEND_IMAGE"
