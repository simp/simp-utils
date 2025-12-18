FROM almalinux:10

RUN dnf -y update \
  && dnf -y install \
    https://yum.voxpupuli.org/openvox8-release-el-10.noarch.rpm \
    epel-release \
    yum-utils \
  && yum-config-manager --set-enabled crb \
  && dnf -y install \
    git \
    openvox-agent \
    openvox-server \
    ruby \
    ruby-devel \
    rubygem-rake \
    libyaml-devel \
    make \
    gcc \
    jq \
    which \
    time \
    vim-enhanced \
    neovim \
    bash-completion \
    sudo \
    createrepo_c \
    genisoimage \
    rpm-build \
  && { \
    dnf -y install yamllint \
    || { dnf -y install python3-pip && pip install yamllint; }; \
  } \
  && dnf clean all

# Create a non-root user and set permissions
RUN useradd -ms /bin/bash vscode \
    && mkdir -p /workspace \
    && chown -R vscode:vscode /workspace \
    && echo vscode ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

# Switch to the non-root user
USER vscode

# Set the working directory
WORKDIR /workspace
