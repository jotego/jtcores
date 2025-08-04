#!/bin/bash
# Packages needed on a fresh Ubuntu 20,04 installation
# Sublime-text isn't really needed for compilation but
# it is the recommended text editor

set -e

# Store arch
raw_arch="$(uname -m)"
case "$raw_arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arch64" ;;
    *) echo "Unkonwn architecture $raw_arch"; exit 1 ;;
esac

# Sublime Text
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list

sudo apt update
sudo apt upgrade --yes

sudo apt install --yes --install-suggests apt-transport-https nfs-common
sudo apt install --yes --install-suggests build-essential git gtkwave figlet xmlstarlet \
    sublime-text 
# repository called docker in ubuntu 20.04, docker.io in ubuntu 24.04    
sudo apt install --yes docker.io
sudo apt install --yes python-is-python3

# Ubuntu only (ignore if alrea error)
sudo apt install --yes libfl2 libfl-dev zlib1g zlib1g-dev 

# required by iverilog
sudo apt install --yes flex gperf bison

# libpng12, required by Quartus 17
cd /tmp
LIBPNG="libpng-1.2.59"
wget https://downloads.sourceforge.net/libpng/$LIBPNG.tar.gz
tar -xvzf $LIBPNG.tar.gz
cd $LIBPNG
./configure
make
sudo make install
rm -rf $LIBPNG $LIBPNG.tar.gz

# required by MAME
sudo apt install --yes libqwt-qt5-dev libsdl2-dev libfontconfig1-dev libsdl2-ttf-dev \
    libfontconfig-dev libpulse-dev qtbase5-dev qtbase5-dev-tools \
    qtchooser qt5-qmake

# jtcore and jtupdate
sudo apt install --yes parallel locate python3-pip fatattr sshpass gawk libxml2-utils
sudo updatedb

# KiCAD
sudo add-apt-repository -y ppa:kicad/kicad-8.0-releases
sudo apt update
sudo apt install --yes occt-misc=7.6.3+dfsg1-7.1build1 libocct-visualization-7.6t64
sudo apt install --yes kicad

# Locale
sudo apt install --yes locales locales-all
sudo locale-gen en_US.UTF-8

# open picoblaze assembler needed for assembling the cheat and beta code
if command -v python3.11 >/dev/null 2>&1; then
    PYTHON=python3.11
else
    sudo apt install -y software-properties-common
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update
    sudo apt install -y python3.11 python3.11-distutils
    PYTHON=python3.11
fi
if ! $PYTHON -m pip --version >/dev/null 2>&1; then
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
    $PYTHON /tmp/get-pip.py --user
fi
PIP="$PYTHON -m pip"

$PIP install --user --upgrade "setuptools<58" "wheel<0.38"
$PIP install --user opbasm

USER_BIN="$HOME/.local/bin"
if ! echo "$PATH" | grep -q "$USER_BIN"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

# as31 to compile 8051/8751 assembler code
sudo apt install --yes as31

# asm48 to compile MCS-48 assembler code
if ! command -v asm48 >/dev/null 2>&1; then
    cd /tmp
    git clone https://github.com/jotego/asm48.git
    cd asm48
    make
    sudo cp 8039dasm asm48 /usr/local/bin
    rm -rf /tmp/asm48
fi

# macro assembler for many, many CPUs
if ! command -v asl >/dev/null 2>&1; then
    cd /tmp
    wget http://john.ccac.rwth-aachen.de:8000/ftp/as/source/c_version/asl-current.tar.gz
    tar xfz asl-current.tar.gz
    cd asl-current
    if [[ "$arch" == "arch64" ]]; then
        ln -s Makefile.def-samples/Makefile.def-arm-apple-linux Makefile.def
    elif [[ "$arch" == "amd64" ]]; then
        ln -s Makefile.def-samples/Makefile.def-x86_64-unknown-linux Makefile.def
    fi
    make
    sudo cp alink asl p2bin p2hex pbind plist /usr/local/bin
    sudo mkdir -p /usr/local/share/man/man1/
    sudo cp man/* /usr/local/share/man/man1/
    rm -rf /tmp/asl-current.tar.gz /tmp/asl-current
fi

# MRA tool to generate .arc files
if ! command -v mra >/dev/null 2>&1; then
    cd /tmp
    git clone https://github.com/mist-devel/mra-tools-c.git
    cd mra-tools-c
    make -j
    sudo mv mra /usr/local/bin/mra
    rm -rf /tmp/mra-tools-c
fi

# Verilator
sudo apt install --yes git help2man perl python3 make autoconf g++ flex bison ccache
sudo apt install --yes libgoogle-perftools-dev numactl perl-doc

if [ ! -d "$HOME/verilator/.git" ]; then
    cd $HOME
    unset VERILATOR_ROOT
    git clone https://github.com/verilator/verilator.git --depth 1 || exit $?
    cd $HOME/verilator
    autoconf
    ./configure
    # compile using 80% of available CPUs
    make -j $((`nproc`*4/5))
    export VERILATOR_ROOT=`pwd`
    echo export VERILATOR_ROOT=`pwd` >> $HOME/.bashrc
fi

# Icarus Verilog
if [ ! -d "$VERILATOR_ROOT/iverilog/.git" ]; then
    cd $VERILATOR_ROOT
    git clone https://github.com/steveicarus/iverilog.git
    cd iverilog
    git checkout v12_0
    sh autoconf.sh
    ./configure
    make -j $((`nproc`*4/5))
    sudo make install
fi

# nice to have
sudo apt install --yes htop flameshot ghex imagemagick

# git configuration
git config --global url.ssh://git@github.com/.insteadOf https://github.com/
git config --global alias.d diff
git config --global alias.co checkout
git config --global alias.st status
git config --global alias.wt worktree
git config --global alias.p pull
git config --global alias.b bisect
git config --global alias.su "submodule update"
git config --global alias.r "reset --hard"
# handling of EOL characters
git config --global core.whitespace cr-at-eol
git config --global core.autocrlf input
# aim for a linear history
git config --global pull.rebase true

# Go
if [[ "$arch" == "arch64" ]]; then
    GONAME=go1.21.3.linux-arm64.tar.gz
elif [[ "$arch" == "amd64" ]]; then
    GONAME=go1.21.3.linux-amd64.tar.gz
fi
wget https://go.dev/dl/$GONAME
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf $GONAME
sudo rm -f $GONAME
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
echo export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin >> $HOME/.bashrc
go install github.com/spf13/cobra-cli@latest
go install golang.org/x/tools/cmd/goimports@latest
go install golang.org/x/tools/cmd/godoc@latest

# GitHub CLI
type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
&& sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& sudo apt update \
&& sudo apt install gh -y

# Set up repositories
cat<<EOF

Run these commands after setting the SSH key in GitHub:

cd $HOME
git clone --recurse-submodules git@github.com:jotego/jtcores.git
mkdir jtmisc
cd jtmisc
git clone --depth 1 --shallow-since="$(date --date='-2 weeks' +%F)" git@github.com:jotego/jtbin.git
git clone git@github.com:jotego/jtbeta.git
git clone git@github.com:JTFPGA/jtutil.git

EOF

# USB Blaster
sudo $JTFRAME/bin/jtblaster

# audio play and visualization
sudo apt install -y mplayer audacity

# Cross-Compiler
# m68k-linux-gnu-gcc
sudo apt install -y gcc-m68k-linux-gnu
