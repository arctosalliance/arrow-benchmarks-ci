#!/bin/bash

# Set NOPASSWD for buildkite-agent user
echo "buildkite-agent ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

# Install Arrow C++ Dependencies
sudo su
yum update -y -q && \
    yum install -y -q \
        autoconf \
        ca-certificates \
        cmake \
        g++ \
        gcc \
        gdb \
        git \
        make \
        ninja-build \
        pkg-config \
        protobuf-compiler \
        tzdata \
        wget

# Install Arrow Python Dependencies
yum update -y -q && \
    yum install -y -q \
        python3 \
        python3-pip

# Install Conda
case $( uname -m ) in
  aarch64)
    conda_installer=Miniconda3-latest-Linux-aarch64.sh;;
  *)
    conda_installer=Miniconda3-latest-Linux-x86_64.sh;;
esac
curl -LO https://repo.anaconda.com/miniconda/$conda_installer
bash $conda_installer -b -p "/var/lib/buildkite-agent/miniconda3"
su - buildkite-agent -c "/var/lib/buildkite-agent/miniconda3/bin/conda init bash"
