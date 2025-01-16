FROM ubuntu:noble
LABEL maintainer="Hamish Arnold h-arnold@github"
LABEL description="PaperCut NG Application Server"

# Creating 'papercut' user
RUN useradd -mUd /papercut -s /bin/bash papercut

# Installing necessary packages including HPLIP and CUPS, and adding 'papercut' user to 'lpadmin' group for printer management
RUN apt-get update && \
    apt-get install -y curl cpio cups hplip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    usermod -aG lpadmin papercut

# Starts the CUPS daemon and enables it at startup
RUN service cups start

# Downloading and installing envsubst for env variable replacements with server.properties.template
ENV ENVSUBST_DOWNLOAD_URL https://github.com/a8m/envsubst/releases/download/v1.1.0/envsubst-Linux-x86_64
RUN curl -L "${ENVSUBST_DOWNLOAD_URL}" -o /usr/local/bin/envsubst && \
    chmod +x /usr/local/bin/envsubst

# Downloading the MySQL connector
ENV MYSQL_CONNECTOR_VERSION 8.0.30
ENV MYSQL_CONNECTOR_DOWNLOAD_URL https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.tar.gz

RUN curl -L "${MYSQL_CONNECTOR_DOWNLOAD_URL}" -o /mysql.tar.gz && \
    tar -xvzf /mysql.tar.gz -C / && \
    rm /mysql.tar.gz

# Install Papercut
ENV PAPERCUT_MAJOR_VER 24.x
ENV PAPERCUT_VER 24.1.1.70969
ENV PAPERCUT_DOWNLOAD_URL https://cdn1.papercut.com/web/products/ng-mf/installers/ng/${PAPERCUT_MAJOR_VER}/pcng-setup-${PAPERCUT_VER}.sh

# Downloading Papercut and ensuring it's executable
RUN curl -L "${PAPERCUT_DOWNLOAD_URL}" -o /pcng-setup.sh && \
    chmod a+rx /pcng-setup.sh && \
    runuser -l papercut -c "/pcng-setup.sh -v --non-interactive" && \
    rm -f /pcng-setup.sh && \
    /papercut/MUST-RUN-AS-ROOT

# Stopping Papercut services before capturing image
RUN /etc/init.d/papercut stop && \
    /etc/init.d/papercut-web-print stop

# Installing the MySQL connector
RUN mv /mysql-connector-java-${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar /papercut/server/lib-ext/ && \
    rm -r /mysql-connector-java-${MYSQL_CONNECTOR_VERSION}

WORKDIR /papercut
VOLUME /papercut/server/data/conf /papercut/server/custom /papercut/server/logs /papercut/server/data/backups /papercut/server/data/archive /etc/cups
EXPOSE 9191 9192 9193 631

COPY server.properties.template /
COPY backup-license.sh /
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN chmod +x /backup-license.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/backup-license.sh"]
