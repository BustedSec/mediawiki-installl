#!/bin/bash

# This script automates the installation of MediaWiki on Debian/Ubuntu
# as described in https://www.mediawiki.org/wiki/Manual:Running_MediaWiki_on_Debian_or_Ubuntu

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Exiting." 
   exit 1
fi

# Ensure Debian is up-to-date
echo "Updating Debian..."
apt update && apt upgrade -y
if [ $? -ne 0 ]; then
  echo "Failed to update Debian. Exiting."
  exit 1
fi

# Install LAMP stack 
echo "Installing Apache, MariaDB, PHP and required extensions..."
apt install -y apache2 mariadb-server php php-mysql libapache2-mod-php php-xml php-mbstring
if [ $? -ne 0 ]; then
  echo "Failed to install LAMP stack. Exiting."
  exit 1  
fi

# Install optional useful packages
echo "Installing optional useful packages..."
apt install -y php-apcu php-intl imagemagick inkscape php-gd php-cli php-curl php-bcmath git
if [ $? -ne 0 ]; then
  echo "Failed to install some optional packages. Continuing anyway."
fi

# Reload Apache to enable php-apcu
echo "Reloading Apache..."
systemctl reload apache2
if [ $? -ne 0 ]; then
  echo "Failed to reload Apache. Exiting."
  exit 1
fi

# Download and extract MediaWiki 
echo "Downloading MediaWiki..."
cd /tmp
wget https://releases.wikimedia.org/mediawiki/1.42/mediawiki-1.42.1.tar.gz
if [ $? -ne 0 ]; then
  echo "Failed to download MediaWiki. Exiting."
  exit 1  
fi

echo "Extracting MediaWiki..."
tar -xvzf /tmp/mediawiki-*.tar.gz
mkdir -p /var/lib/mediawiki
mv mediawiki-*/* /var/lib/mediawiki
if [ $? -ne 0 ]; then
  echo "Failed to extract MediaWiki. Exiting."
  exit 1
fi

# Prompt user for MySQL password
read -s -p "Enter a password for the MySQL 'wiki' user: " MYSQL_PASS
echo

# Configure MySQL
echo "Configuring MySQL..."
mysql -u root <<EOF
CREATE USER 'wiki'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
CREATE DATABASE my_wiki;  
GRANT ALL ON my_wiki.* TO 'wiki'@'localhost';
FLUSH PRIVILEGES;
EOF
if [ $? -ne 0 ]; then
  echo "Failed to configure MySQL. Exiting."
  exit 1  
fi

# Configure PHP
echo "Configuring PHP..."
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 20M/g' /etc/php/7.*/apache2/php.ini
sed -i 's/memory_limit = 8M/memory_limit = 128M/g' /etc/php/7.*/apache2/php.ini
if [ $? -ne 0 ]; then
  echo "Failed to configure PHP. Exiting."
  exit 1
fi

# Enable required PHP extensions 
phpenmod mbstring
phpenmod xml
systemctl restart apache2
if [ $? -ne 0 ]; then
  echo "Failed to enable PHP extensions. Exiting."
  exit 1  
fi

# Create symlink to MediaWiki in web root
ln -s /var/lib/mediawiki /var/www/html/mediawiki
if [ $? -ne 0 ]; then
  echo "Failed to create symlink. Exiting."
  exit 1
fi

echo "MediaWiki installation completed successfully!"
echo "Navigate to http://localhost/mediawiki to configure your wiki."
echo "Remember to use the MySQL password you set earlier in the configuration."
