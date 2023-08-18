#!/usr/bin/env bash
#
# Usage:
#  ./create_as2_image.sh [<image_name>]
#
# Arguments:
#   <image_name>  AppStream 2.0 image name

set -euxo pipefail

# shellcheck disable=SC2154
AWS_REGION="${AWS_Region}"
AWS_ACCOUNT_ID="$( \
  aws --profile appstream_machine_role sts get-caller-identity \
    --query 'Account' --output text \
)"
# shellcheck disable=SC2154
PROJECT_NAME="${AppStream_Resource_Name%-as2-*}"
PROJECT_S3_BUCKET="${PROJECT_NAME}-as2-${AWS_ACCOUNT_ID}"
# shellcheck disable=SC2154
BASE_IMAGE_NAME="${AppStream_Image_Arn##*/}"
IMAGE_NAME="${1:-"${PROJECT_NAME}-as2-$(date +%m-%d-%Y)"}"
IMAGE_DESCRIPTION="$(cat /etc/system-release) with Docker"


# Set timezone
case "${AWS_REGION}" in
  'us-east-1' | 'us-east-2' )           TZ='America/New_York' ;;
  'us-west-1' | 'us-west-2' )           TZ='America/Los_Angeles' ;;
  'ca-central-1' )                      TZ='America/Toronto' ;;
  'sa-east-1' )                         TZ='America/Sao_Paulo' ;;
  'eu-west-1' )                         TZ='Europe/Dublin' ;;
  'eu-west-2' )                         TZ='Europe/London' ;;
  'eu-west-3' )                         TZ='Europe/Paris' ;;
  'eu-north-1' )                        TZ='Europe/Stockholm' ;;
  'eu-central-1' )                      TZ='Europe/Berlin' ;;
  'eu-south-1' )                        TZ='Europe/Rome' ;;
  'ap-south-1' )                        TZ='Asia/Kolkata' ;;
  'ap-southeast-1' )                    TZ='Asia/Singapore' ;;
  'ap-southeast-2' )                    TZ='Australia/Sydney' ;;
  'ap-northeast-1' | 'ap-northeast-3' ) TZ='Asia/Tokyo' ;;
  'ap-northeast-2' )                    TZ='Asia/Seoul' ;;
  'ap-east-1' )                         TZ='Asia/Hong_Kong' ;;
  'af-south-1' )                        TZ='Africa/Johannesburg' ;;
  'me-south-1' )                        TZ='Asia/Dubai' ;;
  * )                                   TZ='UTC' ;;
esac
sudo timedatectl set-timezone "${TZ}"


# Install packages
sudo yum -y upgrade
sudo amazon-linux-extras install -y firefox libreoffice
sudo yum -y install \
  amazon-efs-utils bzip2 ca-certificates colordiff curl docker findutils git \
  gzip ImageMagick jq nkf nmap p7zip pandoc pbzip2 pigz tar time tmux \
  traceroute tree vim-enhanced wget which whois zsh \
  ibus-kkc ipa-gothic-fonts ipa-mincho-fonts vlgothic-p-fonts


# Install Mountpoint for Amazon S3
if [[ ! -f '/usr/bin/mount-s3' ]]; then
  sudo yum -y install \
    https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.rpm
fi


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


# Set environment variables
# shellcheck disable=SC2154
cat << EOF | sudo tee /etc/profile.d/user_env.sh
export GTK_THEME='Adwaita-dark'
export AWS_PROFILE='appstream_machine_role'
export AWS_REGION='${AWS_REGION}'
export AWS_ACCOUNT_ID='${AWS_ACCOUNT_ID}'
export BASE_IMAGE_NAME='${BASE_IMAGE_NAME}'
export PROJECT_NAME='${PROJECT_NAME}'
export PROJECT_S3_BUCKET='${PROJECT_S3_BUCKET}'
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
EFS_FS_ID="\$(echo "\${efs_ap_json}" | jq -r '.FileSystemId')"
EFS_AP_ID="\$(echo "\${efs_ap_json}" | jq -r '.AccessPointId')"

if [[ -n "\${EFS_AP_ID}" ]] && [[ -n "\${EFS_FS_ID}" ]]; then
  [[ -d '/mnt/efs' ]] || sudo mkdir -p /mnt/efs
  sudo mount \
    -t efs -o tls,iam,awsprofile=appstream_machine_role,accesspoint=\${EFS_AP_ID} \
    \${EFS_FS_ID} /mnt/efs
fi

echo "export EFS_FS_ID='\${EFS_FS_ID}'" | sudo tee -a /etc/profile.d/user_env.sh
echo "export EFS_AP_ID='\${EFS_AP_ID}'" | sudo tee -a /etc/profile.d/user_env.sh
EOF
sudo chmod +x /opt/appstream/SessionScripts/mount-efs.sh


# Create a script for mounting S3
cat << EOF | sudo tee /opt/appstream/SessionScripts/mount-s3.sh
#!/usr/bin/env bash

set -euo pipefail

[[ -d '/mnt/s3' ]] || sudo mkdir -p /mnt/s3
sudo /usr/bin/mount-s3 \
  --profile appstream_machine_role --region ${AWS_REGION} --allow-other \
  ${PROJECT_S3_BUCKET} /mnt/s3
EOF
sudo chmod +x /opt/appstream/SessionScripts/mount-s3.sh


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
  --name 'firefox' \
  --display-name 'Firefox' \
  --absolute-app-path '/usr/bin/firefox' \
  --absolute-icon-path '/usr/share/icons/hicolor/256x256/apps/firefox.png'

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
  --absolute-app-path '/usr/bin/libreoffice' \
  --absolute-icon-path '/usr/share/icons/hicolor/256x256/apps/libreoffice-base.png'

sudo AppStreamImageAssistant create-image \
   --name "${IMAGE_NAME}" \
   --display-name "${IMAGE_NAME}" \
   --description "${IMAGE_DESCRIPTION}" \
   --use-latest-agent-version
