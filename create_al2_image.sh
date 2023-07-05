#!/usr/bin/env bash

set -euxo pipefail

IMAGE_NAME='al2-with-docker'
IMAGE_DESCRIPTION="$(cat /etc/system-release) with Docker"

# shellcheck disable=SC2154
AWS_REGION="${AWS_Region}"
AWS_ACCOUNT_ID="$( \
  aws --profile appstream_machine_role sts get-caller-identity \
    --query 'Account' --output text \
)"
# shellcheck disable=SC2154
PROJECT_NAME="${AppStream_Resource_Name%%-appstream-*}"


# Install packages
sudo yum -y upgrade
sudo yum -y install \
  amazon-efs-utils bzip2 cargo clang-devel cmake3 colordiff curl docker \
  findutils fuse-devel git gzip ImageMagick jq nkf p7zip pandoc pbzip2 pigz \
  tar time tmux traceroute tree vim-enhanced wget which whois zsh \
  ibus-kkc ipa-gothic-fonts ipa-mincho-fonts vlgothic-p-fonts


# Install Google Chrome
if [[ ! -f '/usr/bin/google-chrome-stable' ]]; then
  sudo yum -y install \
    https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
fi


# Install Visual Studio Code
if [[ ! -f '/usr/bin/code' ]]; then
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  cat << EOF | sudo tee /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
  yum check-update
  sudo yum -y install code
fi


# Install LibreOffice
if [[ $(find '/usr/bin' -name 'libreoffice*' | wc -l) -eq 0 ]]; then
  curl -SL https://www.libreoffice.org/download/download-libreoffice/ \
    | grep -oe 'version=[0-9]\+\.[0-9]\+\.[0-9]\+' \
    | head -1 \
    | cut -d = -f 2 \
    | xargs -I{} curl -SL -o /tmp/libreoffice.tar.gz \
      https://download.documentfoundation.org/libreoffice/stable/{}/rpm/x86_64/LibreOffice_{}_Linux_x86-64_rpm.tar.gz
  tar xvf /tmp/libreoffice.tar.gz -C /tmp --remove-files
  sudo yum -y install /tmp/LibreOffice_*_Linux_x86-64_rpm/RPMS/*.rpm
  rm -rf /tmp/LibreOffice_*
fi


# Remove cache data
sudo yum clean all
sudo rm -rf /var/cache/yum


# Install AWS CLI v2
if [[ ! -f '/usr/local/bin/aws' ]]; then
  curl -SL -o /tmp/awscliv2.zip \
    https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
  unzip -d /tmp /tmp/awscliv2.zip
  sudo /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi


# Install Python packages
sudo python3 -m pip install -U --no-cache-dir \
  csvkit docker-compose yamllint


# Install mountpoint-s3
#if [[ ! -f '/opt/mountpoint-s3/target/release/mount-s3' ]]; then
#  git clone --depth 1 --recurse-submodules \
#    https://github.com/awslabs/mountpoint-s3.git
#  sudo mv mountpoint-s3 /opt/
#  cd /opt/mountpoint-s3
#  cargo build --release
#  cd -
#fi


# Set environment variables
# shellcheck disable=SC2154
cat << EOF | sudo tee /etc/profile.d/user_env.sh
export GTK_THEME='Adwaita-dark'
export AWS_PROFILE='appstream_machine_role'
export AWS_REGION='${AWS_REGION}'
export AWS_ACCOUNT_ID='${AWS_ACCOUNT_ID}'
EOF


# Enable Docker
sudo systemctl enable docker.service
sudo systemctl enable containerd.service


# Add as2-streaming-user
[[ $(grep -ce 'as2-streaming-user' /etc/passwd) -gt 0 ]] \
  || sudo useradd -m as2-streaming-user
printf "as2-streaming-user\tALL=(ALL)\tNOPASSWD: ALL\n" \
  | sudo tee /etc/sudoers.d/as2-streaming-user
sudo usermod -aG docker as2-streaming-user


# Create a script for mounting EFS
sudo cp -r ~/.aws /root/
cat << EOF | sudo tee /opt/appstream/SessionScripts/mount-efs.sh
#!/usr/bin/env bash

set -euo pipefail

efs_ap_json="\$( \
  aws --profile appstream_machine_role --region ${AWS_REGION} efs describe-access-points \
    | jq ".AccessPoints[] | select(.Name == \\"${PROJECT_NAME}-efs-accesspoint\\")" \
)"
efs_fs_id="\$(echo "\${efs_ap_json}" | jq -r '.FileSystemId')"
efs_ap_id="\$(echo "\${efs_ap_json}" | jq -r '.AccessPointId')"

if [[ -n "\${efs_ap_id}" ]] && [[ -n "\${efs_fs_id}" ]]; then
  [[ -d '/mnt/efs' ]] || sudo mkdir -p /mnt/efs
  sudo mount -t efs -o tls,accesspoint=\${efs_ap_id} \${efs_fs_id} /mnt/efs
fi
EOF
sudo chmod +x /opt/appstream/SessionScripts/mount-efs.sh


# Create a script for mounting S3
#s3_bucket_name="${PROJECT_NAME}-appstream-${AWS_ACCOUNT_ID}"
#cat << EOF | sudo tee /opt/appstream/SessionScripts/mount-s3.sh
##!/usr/bin/env bash
#
#set -euo pipefail
#
#[[ -d '/mnt/s3' ]] || sudo mkdir -p /mnt/s3
#sudo /opt/mountpoint-s3/target/release/mount-s3 \
#  --profile appstream_machine_role --region ${AWS_REGION} --allow-other \
#  ${s3_bucket_name} /mnt/s3
#EOF
#sudo chmod +x /opt/appstream/SessionScripts/mount-s3.sh


# Configure AppStream 2.0 session scripts
cat << EOF | sudo tee /opt/appstream/SessionScripts/config.json
{
  "SessionStart": {
    "executables": [
      {
        "Context": "system",
        "Filename": "/opt/appstream/SessionScripts/mount-efs.sh",
        "Arguments": "",
        "S3LogEnabled": true
      }
    ],
    "waitingTime": 30
  },
  "SessionTermination": {
    "executables": [],
    "waitingTime": 30
  }
}
EOF


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

sudo AppStreamImageAssistant add-application \
  --name 'libreoffice' \
  --display-name 'LibreOffice' \
  --absolute-app-path \
  "$(find '/usr/bin' -name 'libreoffice*' | head -1)" \
  --absolute-icon-path \
  "$(find '/usr/share/icons/hicolor/256x256/apps' -name 'libreoffice*-base.png' | head -1)"

sudo AppStreamImageAssistant create-image \
   --name "${IMAGE_NAME}" \
   --display-name "${IMAGE_NAME}" \
   --description "${IMAGE_DESCRIPTION}" \
   --use-latest-agent-version
