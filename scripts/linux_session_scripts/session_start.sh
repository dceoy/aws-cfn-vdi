#!/usr/bin/env bash

set -euxo pipefail

yum -y upgrade
yum -y groupinstall 'Development tools'
yum install -y \
  colordiff curl docker git go jq kernel-devel lua-devel luajit-devel nginx \
  nkf nmap npm p7zip pandoc pbzip2 pigz python3-devel python3-pip R-devel \
  ruby-devel shunit2 sqlite-devel sudo time tmux traceroute tree vim-enhanced \
  wget whois zsh

python3 -m pip install -U --no-cache-dir \
  csvkit docker-compose flake8 flake8-bugbear flake8-isort grip jupyterlab \
  pandas pep8-naming vim-vint vulture yamllint

curl -SL -o /tmp/awscliv2.zip \
  https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
unzip -d /tmp /tmp/awscliv2.zip
/tmp/aws/install
