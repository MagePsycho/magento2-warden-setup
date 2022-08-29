# Magento 2 Warden Setup
A simple utility script to set up the warden for your Magento 2 development (from existing project or vanilla installation)

## INSTALL
You can simply download the script file and give the executable permission.
```
curl -0 https://raw.githubusercontent.com/MagePsycho/magento2-warden-setup/master/src/m2-warden-setup.sh -o m2-warden-setup.sh
chmod +x m2-warden-setup.sh
```

To make it system-wide command (recommended)
```
mv m2-warden-setup.sh ~/bin/m2-warden-setup
#OR
#mv m2-warden-setup.sh /usr/local/bin/m2-warden-setup
```

You also need a config file `.m2-warden-setup.conf` to configure the Magento 2 project.    
The config template can be downloaded as
```
curl -0 https://raw.githubusercontent.com/MagePsycho/magento2-warden-setup/master/.m2-warden-setup.conf.dist -o .m2-warden-setup.conf
```
*Note: `.m2-warden-setup.conf` file should reside in your local project directory.*
