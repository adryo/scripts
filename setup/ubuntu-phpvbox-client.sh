#!/usr/bin/env bash

PHPVBOX_VERSION="5.2-1"

LOGON_PASSWORD=${CURRENT_LOGON_PASSWORD:-$1}

echo "Starting installation of PHP VBox Client v$PHPVBOX_VERSION"

echo "Requesting to install dependencies..."
sudo apt install unzip apache2 php7.2 php7.2-mysql libapache2-mod-php php7.2-xml -y

if ! sudo apt install php7.2-soap -y; then
    wget http://security.ubuntu.com/ubuntu/pool/universe/p/php7.2/php7.2-soap_7.2.15-0ubuntu0.18.04.1_amd64.deb
    sudo dpkg -i php7.2-soap*
    rm php7.2-soap*
fi
if [ "$?" -ne "0" ]; then
    echo "Unable to install dependencies. Stoping installation"
    exit 1
fi

PHPVBOX_PACKAGE="${PHPVBOX_VERSION}.zip"
echo "Resolving package $PHPVBOX_PACKAGE"
if wget https://github.com/phpvirtualbox/phpvirtualbox/archive/$PHPVBOX_PACKAGE && unzip $PHPVBOX_PACKAGE; then
    rm $PHPVBOX_PACKAGE
    sudo mv phpvirtualbox-${PHPVBOX_VERSION}/ /var/www/html/phpvirtualbox
    sudo chmod 777 -R /var/www/html/phpvirtualbox/
    echo "PHP VBox client installed!"

    echo "Configuring client ..."

    cp /var/www/html/phpvirtualbox/config.php-example /var/www/html/phpvirtualbox/config.php

    echo "Installed default config file ..."

    sed -i -e "s/var \$username = 'vbox';/var \$username = '$USER';/g" /var/www/html/phpvirtualbox/config.php

    if [ -z "$LOGON_PASSWORD" ]; then
        read -s -p "Password (for $USER): " LOGON_PASSWORD
        echo ""
    fi
    
    sed -i -e "s/var \$password = 'pass';/var \$password = '$LOGON_PASSWORD';/g" /var/www/html/phpvirtualbox/config.php

    echo "Setting up credentials ..."

    sudo /bin/sh -c "echo VBOXWEB_USER=$USER >> /etc/default/virtualbox"

    echo "Configured default user for vbox service ..."

    echo "Requesting services to restart..."

    sudo systemctl restart vboxweb-service
    sudo systemctl restart vboxdrv
    sudo systemctl restart apache2

    echo "Enabling configuration in firewall..."
    sudo ufw allow in "Apache Full"

    echo "Done!"
fi
