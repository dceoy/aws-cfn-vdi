#!/usr/bin/env bash

set -euxo pipefail

IMAGE_NAME='al2-with-docker'
IMAGE_DESCRIPTION="$(cat /etc/system-release) with Docker"


# Install packages
sudo yum -y upgrade
sudo yum -y install \
  colordiff curl docker git ImageMagick jq nkf p7zip pandoc pbzip2 pigz time \
  tmux traceroute tree vim-enhanced wget whois zsh \
  ibus-kkc ipa-gothic-fonts ipa-mincho-fonts vlgothic-p-fonts

[[ -f '/usr/bin/google-chrome-stable' ]] \
  || sudo yum -y install \
    https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm

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

sudo yum clean all
sudo rm -rf /var/cache/yum

sudo python3 -m pip install -U --no-cache-dir \
  csvkit docker-compose yamllint


# Update system configurations
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
sudo ln -sf /usr/bin/google-chrome-stable /usr/bin/chromium
echo "GTK_THEME='Adwaita-dark'" | sudo tee /etc/profile.d/gtk-theme.sh


# Configure session scripts
sudo sed -i \
  -e 's/^\(wheel:x:[0-9]\+:ec2-user\)$/\1,as2-streaming-user/' \
  -e 's/^\(docker:x:[0-9]\+:\)$/\1as2-streaming-user/' \
  /etc/group


# Create an AppStream 2.0 image
sudo AppStreamImageAssistant add-application \
  --name 'gnome-terminal' \
  --display-name 'Terminal' \
  --absolute-app-path '/usr/bin/gnome-terminal' \
  --absolute-icon-path '/usr/share/icons/gnome/256x256/apps/utilities-terminal.png'
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
