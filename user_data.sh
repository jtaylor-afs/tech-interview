#!/bin/bash

echo "Installing apt packages" >> /var/log/passage.log
yum update -y
yum install -y git wget unzip bsdtar

echo "Cloning git repositories" >> /var/log/passage.log
git clone https://github.com/eficode-academy/kubernetes-katas.git /home/ec2-user/kubernetes-katas
git clone https://github.com/jtaylor-afs/tech-interview.git /home/ec2-user/tech-interview

MAC=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/ | sed 's/\///') && export internal_ip=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/$MAC/local-ipv4s)
MAC=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/ | sed 's/\///') && export public_ip=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/$MAC/public-ipv4s)

# Start the VS Code server and expose the clear text port
echo "Starting VS Code" >> /var/log/passage.log
mkdir -p /home/ec2-user/letsencrypt/nginx/proxy-confs/
sed -i "s/code/1234/g" /home/ec2-user/tech-interview/config/code.subdomain.conf
sed -i "s/192.168.1.1/$internal_ip/g" /home/ec2-user/tech-interview/config/code.subdomain.conf

cp /home/ec2-user/tech-interview/config/code.subdomain.conf /home/ec2-user/letsencrypt/nginx/proxy-confs/code.subdomain.conf
chown -R 1000:1000 /home/ec2-user/letsencrypt/
docker run -d --name=code-server -e TZ=America/Chicago -e PUID=1000 -e PGID=1000 -e PASSWORD=Password123 -e SUDO_PASSWORD=Password123 -e DEFAULT_WORKSPACE=/config/workspace -p 8443:8443 -v /home/ec2-user/:/config --restart unless-stopped lscr.io/linuxserver/code-server:latest
docker run -d --name=swag --cap-add=NET_ADMIN -e PUID=1000 -e PGID=1000 -e TZ=America/Chicago -e URL=wooden-proton.com -e SUBDOMAINS=1234 -e VALIDATION=http -e EMAIL=jt@conft.io -e DHLEVEL=2048 -e ONLY_SUBDOMAINS=true -e STAGING=false -p 443:443 -p 80:80 -v /home/ec2-user/letsencrypt/:/config --restart unless-stopped linuxserver/swag

# Give VS Code and SWAG time to come up and populate certs
sleep 20

# Install required packages into the code-server
echo "Installing dependencies for VS Code" >> /var/log/passage.log
docker exec code-server sudo apt update
docker exec code-server sudo apt install python3 pip vim -y

# Populate default workspaces and install extensions
echo "Installing VS Code extensions" >> /var/log/passage.log
mkdir -p /home/ec2-user/workspace/devops-engineer /home/ec2-user/workspace/software-engineer /home/ec2-user/bin /home/ec2-user/data/User  /home/ec2-user/extensions
wget https://github.com/jtaylor-afs/tech-interview/releases/download/0.0.1/hediet.vscode-drawio-1.6.4.vsix
wget https://github.com/jtaylor-afs/tech-interview/releases/download/0.0.1/MS-vsliveshare.vsliveshare-1.0.5762.vsix
bsdtar -xvf MS-vsliveshare.vsliveshare-1.0.5762.vsix
mv extension /home/ec2-user/extensions/ms-vsliveshare.vsliveshare-pack-1.0.5762
bsdtar -xvf hediet.vscode-drawio-1.6.4.vsix
mv extension /home/ec2-user/extensions/hediet.vscode-drawio-1.6.4-universal

cp -R /home/ec2-user/kubernetes-katas/ /home/ec2-user/workspace/devops-engineer/
cp /home/ec2-user/tech-interview/config/settings.json /home/ec2-user/data/User/settings.json
touch /home/ec2-user/workspace/whiteboard.drawio

# Retrieve K8s binaries
echo "Installing Kubernetes (K3s)" >> /var/log/passage.log
wget https://github.com/k3s-io/k3s/releases/download/v1.25.3%2Bk3s1/k3s -O /usr/bin/k3s
wget https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl -O /home/ec2-user/bin/kubectl
chmod +x /home/ec2-user/bin/kubectl

# Start and setup Kubernetes
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
mkdir -p /home/ec2-user/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config

# Setup K8s api access inside VS Code terminal
sed -i "s/127.0.0.1/$internal_ip/g" /home/ec2-user/.kube/config
chown -R 1000:1000 /home/ec2-user

printf "
#############################
# tech-interview installation
#        complete 
#############################\n"
