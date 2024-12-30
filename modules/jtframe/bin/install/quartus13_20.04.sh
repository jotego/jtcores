#!/bin/bash
# This will set up the libraries required to run Quartus 13 on Ubuntu 20.04
# Quartus 13.1 should be already installed at /opt/altera/13.1
# Run with sudo

# Get 
dpkg --add-architecture i386
apt update
apt install make:i386 libxdmcp6:i386 libxau6:i386 libxext6:i386 libxft-dev:i386 \
	libxft2:i386 libxrender1:i386 libxt6:i386 libfontconfig1-dev:i386 \
	libxtst6:i386 libx11-6:i386 unixodbc:i386 libzmq3-dev:i386 \
	libxext6:i386 libxi6:i386
# Missing ncurses-base:i386	

DIR=`mktemp --directory`
cd $DIR
wget http://se.archive.ubuntu.com/ubuntu/pool/main/libp/libpng/libpng12-0_1.2.54-1ubuntu1_i386.deb
DIR2=`mktemp --directory`
dpkg -x libpng12-0_1.2.54-1ubuntu1_i386.deb $DIR2
cp $DIR2/lib/i386-linux-gnu/* /usr/lib32

# Create a script to run quartus13
cat > /usr/bin/q13 <<EOF
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:.
PATH=$PATH:/opt/altera/13.1/quartus/bin:/opt/altera/13.1/quartus/linux
export PATH
quartus
EOF
chmod +x /usr/bin/q13