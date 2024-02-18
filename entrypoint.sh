#!/bin/bash

# Fixing permissions after any volume mounts.
chown -R papercut:papercut /papercut
chmod +x /papercut/server/bin/linux-x64/setperms
/papercut/server/bin/linux-x64/setperms

# Check if CUPS is running, start it if it isn't
if ! pgrep -x "cupsd" > /dev/null
then
    echo "CUPS is not running, starting CUPS..."
    service cups start
else
    echo "CUPS is already running."
fi

#Starts 

# Perform only if PaperCut service exists and is executable.
if [[ -x /etc/init.d/papercut ]]; then

    # set server config with env vars
    if [[ ! -d /papercut/server/server.properties ]]; then
        echo "Setting server config"
        runuser -p papercut -c "envsubst < /server.properties.template > /papercut/server/server.properties"
    fi

    # database needs to be initialized
    echo `runuser -l papercut -c "/papercut/server/bin/linux-x64/db-tools init-db -q"`

    # If an import hasn't been done before and a database backup file named
    # 'import.zip' exists, perform import.
    if [[ -f /papercut/import.zip ]] && [[ ! -f /papercut/import.log ]]; then
        echo `runuser -l papercut -c "/papercut/server/bin/linux-x64/db-tools import-db -q -f /papercut/import.zip"`
    fi

    # Copy license file from backup 
    if [[ -f /papercut/server/data/conf/application.license ]]; then
        echo "Restore license file"
        runuser -p papercut -c "cp /papercut/server/data/conf/application.license /papercut/server/application.license"
    fi

    echo "Run license backup script in background"
    exec /backup-license.sh &

    echo "Starting PaperCut service in console"
    exec /etc/init.d/papercut console
else
    echo "PaperCut service not found/executable, maybe the docker image/build got corrupted? Exiting..."
fi
