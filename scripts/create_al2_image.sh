#!/usr/bin/env bash

set -euxo pipefail

IMAGE_NAME='al2-with-docker'
IMAGE_DESCRIPTION="$(cat /etc/system-release) with Docker"


# Install packages
sudo yum -y upgrade
sudo yum -y install \
  amazon-efs-utils aws-cli bzip2 colordiff curl docker findutils git gzip \
  ImageMagick jq nkf p7zip pandoc pbzip2 pigz tar time tmux traceroute tree \
  vim-enhanced wget which whois zsh \
  ibus-kkc ipa-gothic-fonts ipa-mincho-fonts vlgothic-p-fonts


# Install Google Chrome
[[ -f '/usr/bin/google-chrome-stable' ]] \
  || sudo yum -y install \
    https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm


# Install Visual Studio Code
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat << 'EOF' | sudo tee /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
yum check-update
sudo yum -y install code


# Install LibreOffice
curl -SL https://www.libreoffice.org/download/download-libreoffice/ \
  | grep -oe 'version=[0-9]\+\.[0-9]\+\.[0-9]\+' \
  | head -1 \
  | cut -d = -f 2 \
  | xargs -I{} curl -SL -o /tmp/libreoffice.tar.gz \
    https://download.documentfoundation.org/libreoffice/stable/{}/rpm/x86_64/LibreOffice_{}_Linux_x86-64_rpm.tar.gz
tar xvf /tmp/libreoffice.tar.gz -C /tmp --remove-files
sudo yum -y install /tmp/LibreOffice_*_Linux_x86-64_rpm/RPMS/*.rpm
rm -rf /tmp/LibreOffice_*


# Remove cache data
sudo yum clean all
sudo rm -rf /var/cache/yum


# Install Python packages
sudo python3 -m pip install -U --no-cache-dir \
  csvkit docker-compose yamllint


# Update system configurations
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

sudo ln -sf /usr/bin/google-chrome-stable /usr/bin/chromium
[[ $(grep -ce '^GTK_THEME=' /etc/environment) -gt 0 ]] \
  || printf "GTK_THEME='Adwaita-dark'\n" | sudo tee /etc/environment

printf "as2-streaming-user\tALL=(ALL)\tNOPASSWD: ALL\n" \
  | sudo tee /etc/sudoers.d/as2-streaming-user

[[ $(grep -ce 'as2-streaming-user' /etc/passwd) -gt 0 ]] \
  || sudo useradd -m as2-streaming-user
sudo usermod -aG docker as2-streaming-user


# Create an AppStream 2.0 image
sudo AppStreamImageAssistant add-application \
  --name 'gnome-terminal' \
  --display-name 'Terminal' \
  --absolute-app-path '/usr/bin/gnome-terminal' \
  --absolute-icon-path '/usr/share/icons/gnome/256x256/apps/utilities-terminal.png' \
  --launch-parameters '"--working-directory=/home/as2-streaming-user"'
sudo AppStreamImageAssistant add-application \
  --name 'google-chrome' \
  --display-name 'Google Chrome' \
  --absolute-app-path '/usr/bin/google-chrome-stable' \
  --absolute-icon-path '/usr/share/icons/hicolor/256x256/apps/google-chrome.png'
convert /usr/share/pixmaps/vscode.png -resize 256x256 /tmp/vscode.png
sudo AppStreamImageAssistant add-application \
  --name 'visual-studio-code' \
  --display-name 'Visual Studio Code' \
  --absolute-app-path '/usr/bin/code' \
  --absolute-icon-path '/tmp/vscode.png'
sudo AppStreamImageAssistant create-image \
   --name "${IMAGE_NAME}" \
   --display-name "${IMAGE_NAME}" \
   --description "${IMAGE_DESCRIPTION}" \
   --use-latest-agent-version
