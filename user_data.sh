#!/bin/bash

tls=tls_enabled

echo "Installing yum packages on the host" >> /var/log/passage.log
yum update -y
yum install -y git wget unzip bsdtar

echo "Cloning git repositories" >> /var/log/passage.log
git clone https://github.com/jtaylor-afs/workspace.git /home/ec2-user/workspace
git clone https://github.com/jtaylor-afs/tech-interview.git /home/ec2-user/tech-interview

# Gather internal and external IP
MAC=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/ | sed 's/\///') && export internal_ip=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/$MAC/local-ipv4s)
MAC=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/ | sed 's/\///') && export public_ip=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/$MAC/public-ipv4s)

# Start the VS Code server and expose the clear text port
echo "Starting VS Code and SWAG" >> /var/log/passage.log
mkdir -p /home/ec2-user/letsencrypt/nginx/proxy-confs/
sed -i "s/code/1234/g" /home/ec2-user/tech-interview/config/code.subdomain.conf
sed -i "s/192.168.1.1/$internal_ip/g" /home/ec2-user/tech-interview/config/code.subdomain.conf
echo " - Starting container(s)" >> /var/log/passage.log

# Install docker and SWAG (lets encypt and nginx proxy)
cp /home/ec2-user/tech-interview/config/code.subdomain.conf /home/ec2-user/letsencrypt/nginx/proxy-confs/code.subdomain.conf
chown -R 1000:1000 /home/ec2-user/letsencrypt/
docker run -d --name=code-server -e DOCKER_MODS='linuxserver/mods:code-server-docker|linuxserver/mods:code-server-extension-arguments' -e VSCODE_EXTENSION_IDS='hediet.vscode-drawio|golang.Go|ms-vsliveshare.vsliveshare|ms-python.python|vscjava.vscode-java-pack|ms-kubernetes-tools.vscode-kubernetes-tools' -e EXTENSIONS_GALLERY='{"serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery", "cacheUrl": "https://vscode.blob.core.windows.net/gallery/index", "itemUrl": "https://marketplace.visualstudio.com/items"}' -e TZ=America/Chicago -e PUID=1000 -e PGID=1000 -e PASSWORD=Password123 -e SUDO_PASSWORD=Password123 -e DEFAULT_WORKSPACE=/config/workspace -p 8443:8443 -v /home/ec2-user/:/config --restart unless-stopped lscr.io/linuxserver/code-server:latest
if [ "$tls" = true ]; then
    docker run -d --name=swag --cap-add=NET_ADMIN -e PUID=1000 -e PGID=1000 -e TZ=America/Chicago -e URL=wooden-proton.com -e SUBDOMAINS=1234 -e VALIDATION=http -e EMAIL=jt@conft.io -e DHLEVEL=2048 -e ONLY_SUBDOMAINS=true -e STAGING=false -p 443:443 -p 80:80 -v /home/ec2-user/letsencrypt/:/config --restart unless-stopped linuxserver/swag
    # Give VS Code and SWAG time to come up and populate certs
    echo " - Waiting on SECURE UI healthcheck (usually takes a few minutes)" >> /var/log/passage.log
    while [[ ${uistatus} != *"200"* ]]; do
        sleep 1
        uistatus=$(curl -s --head -m2 --request GET https://1234.wooden-proton.com --connect-to '1234.wooden-proton.com:localhost' -L | grep HTTP)
    done
else
    # if insecure, check for 200 status on insecure code-server connection
    echo " - Waiting on INSECURE UI healthcheck (usually takes a few minutes)" >> /var/log/passage.log
    while [[ ${uistatus} != *"200"* ]]; do
        sleep 1
        uistatus=$(curl -s --head -m2 --request GET http://"$public_ip":8443 -L | grep HTTP)
    done
fi


# Install required packages into the code-server
# install vim - needed for `kubectl edit` interaction
docker exec code-server sudo apt update
docker exec code-server sudo apt install vim -y

# Setup SSH access from code-server to node
mkdir -p /home/ec2-user/bin /home/ec2-user/data/User  /home/ec2-user/extensions
ssh-keygen -f /home/ec2-user/mykey -N ""
cat /home/ec2-user/mykey.pub >> /home/ec2-user/.ssh/authorized_keys
touch /home/ec2-user/bin/shell
echo "ssh -i /config/mykey -o stricthostkeychecking=no ec2-user@$internal_ip" > /home/ec2-user/bin/shell
chmod +x /home/ec2-user/bin/shell

# Setting up default code-server settings
cp /home/ec2-user/tech-interview/config/settings.json /home/ec2-user/data/User/settings.json
cp /home/ec2-user/tech-interview/config/whiteboard.drawio /home/ec2-user/workspace/whiteboard.drawio

# Fix workspace for insecure deployments
if [ "$tls" = false ] ; then
    # if insecure, change md to html so docs can still be viewed
    # md only fails because for tls deployments, they open in preview mode
    find /home/ec2-user/workspace/ -depth -name "*.md" -exec sh -c 'mv "$1" "${1%.md}.html"' _ {} \;
    # change html files to still render as markdown for easier reading
    sed -i '/"workbench.colorTheme": "Monokai",/a \ \ \ \ "files.associations": { "*.html": "markdown" },' /home/ec2-user/data/User/settings.json
fi

# Retrieve K8s binaries
echo "Installing Kubernetes (K3s)" >> /var/log/passage.log
wget https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl -O /home/ec2-user/bin/kubectl
chmod +x /home/ec2-user/bin/kubectl
cp /home/ec2-user/bin/kubectl /home/ec2-user/bin/k

# Start and setup Kubernetes
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
mkdir -p /home/ec2-user/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config

# Prepare DevOps Engineer questions
kubectl create ns question2
kubectl apply -n question2 -f /home/ec2-user/tech-interview/config/k8s-question2.yaml

# Setup K8s api access inside VS Code terminal
sed -i "s/127.0.0.1/$internal_ip/g" /home/ec2-user/.kube/config
chown -R 1000:1000 /home/ec2-user

printf "\n***Installation complete ***\n" >> /var/log/passage.log
pkill -f tail