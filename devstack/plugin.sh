#
# (C) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
# Copyright 2016 FUJITSU LIMITED
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Monasca DevStack plugin
#
# Install and start Monasca service in devstack
#
# To enable Monasca in devstack add an entry to local.conf that
# looks like
#
# [[local|localrc]]
# enable_plugin monasca https://git.openstack.org/openstack/monasca-api
#
# By default all Monasca services are started (see
# devstack/settings). To disable a specific service use the
# disable_service function. For example to turn off notification:
#
# disable_service monasca-notification
#
# Several variables set in the localrc section adjust common behaviors
# of Monasca (see within for additional settings):
#
# EXAMPLE VARS HERE

# Save trace setting
XTRACE=$(set +o | grep xtrace)
set -o xtrace

ERREXIT=$(set +o | grep errexit)
set -o errexit

# Set default implementations to python
export MONASCA_API_IMPLEMENTATION_LANG=${MONASCA_API_IMPLEMENTATION_LANG:-python}
export MONASCA_PERSISTER_IMPLEMENTATION_LANG=${MONASCA_PERSISTER_IMPLEMENTATION_LANG:-python}

# Set default metrics DB to InfluxDB
export MONASCA_METRICS_DB=${MONASCA_METRICS_DB:-influxdb}

# Set INFLUXDB_VERSION
if [[ "${MONASCA_API_IMPLEMENTATION_LANG,,}" == 'java' ]]; then

    INFLUXDB_VERSION=${INFLUXDB_VERSION:-${INFLUXDB_JAVA_VERSION}}

elif [[ "${MONASCA_API_IMPLEMENTATION_LANG,,}" == 'python' ]]; then

    INFLUXDB_VERSION=${INFLUXDB_VERSION:-${INFLUXDB_PYTHON_VERSION}}

else

    echo "Found invalid value for variable MONASCA_API_IMPLEMENTATION_LANG: $MONASCA_API_IMPLEMENTATION_LANG"
    echo "Valid values for MONASCA_API_IMPLEMENTATION_LANG are \"java\" and \"python\""
    die "Please set MONASCA_API_IMPLEMENTATION_LANG to either \"java'' or \"python\""

fi

# Determine password for database (copied from devstack/lib/database)
if [ -n "$MYSQL_PASSWORD" ]; then
    DATABASE_PASSWORD=$MYSQL_PASSWORD
fi

# db users
MON_DB_USERS=("notification" "monapi" "thresh")
MON_DB_HOSTS=("%" "localhost" "$MYSQL_HOST")

function pre_install_monasca {
:
}

function install_monasca {
    if [[ -n ${SCREEN_LOGDIR} ]]; then
        sudo ln -sf /var/log/influxdb/influxd.log ${SCREEN_LOGDIR}/screen-influxdb.log

        sudo ln -sf /var/log/monasca/api/monasca-api.log ${SCREEN_LOGDIR}/screen-monasca-api.log

        sudo ln -sf /var/log/monasca/persister/persister.log ${SCREEN_LOGDIR}/screen-monasca-persister.log || true

        sudo ln -sf /var/log/monasca/notification/notification.log ${SCREEN_LOGDIR}/screen-monasca-notification.log || true

        sudo ln -sf /var/log/monasca/agent/statsd.log ${SCREEN_LOGDIR}/screen-monasca-agent-statsd.log
        sudo ln -sf /var/log/monasca/agent/supervisor.log ${SCREEN_LOGDIR}/screen-monasca-agent-supervisor.log
        sudo ln -sf /var/log/monasca/agent/collector.log ${SCREEN_LOGDIR}/screen-monasca-agent-collector.log
        sudo ln -sf /var/log/monasca/agent/forwarder.log ${SCREEN_LOGDIR}/screen-monasca-agent-forwarder.log

        sudo ln -sf /var/log/storm/access.log ${SCREEN_LOGDIR}/screen-monasca-thresh-access.log
        sudo ln -sf /var/log/storm/supervisor.log ${SCREEN_LOGDIR}/screen-monasca-thresh-supervisor.log
        sudo ln -sf /var/log/storm/metrics.log ${SCREEN_LOGDIR}/screen-monasca-thresh-metrics.log
        sudo ln -sf /var/log/storm/nimbus.log  ${SCREEN_LOGDIR}/screen-monasca-thresh-nimbus.log
        sudo ln -sf /var/log/storm/worker-6701.log ${SCREEN_LOGDIR}/screen-monasca-thresh-worker-6701.log
        sudo ln -sf /var/log/storm/worker-6702.log ${SCREEN_LOGDIR}/screen-monasca-thresh-worker-6702.log
    fi

    install_git

    update_maven

    install_monasca_virtual_env

    install_openjdk_8_jdk

    install_kafka

    if [[ "${MONASCA_METRICS_DB,,}" == 'influxdb' ]]; then

        install_monasca_influxdb

    elif [[ "${MONASCA_METRICS_DB,,}" == 'vertica' ]]; then

        install_monasca_vertica

    elif [[ "${MONASCA_METRICS_DB,,}" == 'cassandra' ]]; then

        install_monasca_cassandra

    else

        echo "Found invalid value for variable MONASCA_METRICS_DB: $MONASCA_METRICS_DB"
        echo "Valid values for MONASCA_METRICS_DB are \"influxdb\", \"vertica\" and \"cassandra\""
        die "Please set MONASCA_METRICS_DB to either \"influxdb\", \"vertica\" or \"cassandra\""

    fi

    install_cli_creds

    install_maven

    download_monasca_libraries

    if [[ "${MONASCA_API_IMPLEMENTATION_LANG,,}" == 'java' ]]; then

        install_monasca_api_java

    elif [[ "${MONASCA_API_IMPLEMENTATION_LANG,,}" == 'python' ]]; then

        install_monasca_api_python

    else

        echo "Found invalid value for variable MONASCA_API_IMPLEMENTATION_LANG: $MONASCA_API_IMPLEMENTATION_LANG"
        echo "Valid values for MONASCA_API_IMPLEMENTATION_LANG are \"java\" and \"python\""
        die "Please set MONASCA_API_IMPLEMENTATION_LANG to either \"java'' or \"python\""

    fi

    sudo systemctl enable monasca-api

    if is_service_enabled monasca-persister; then
        if [[ "${MONASCA_PERSISTER_IMPLEMENTATION_LANG,,}" == 'java' ]]; then

            install_monasca_persister_java

        elif [[ "${MONASCA_PERSISTER_IMPLEMENTATION_LANG,,}" == 'python' ]]; then

            install_monasca_persister_python

        else

            echo "Found invalid value for varible MONASCA_PERSISTER_IMPLEMENTATION_LANG: $MONASCA_PERSISTER_IMPLEMENTATION_LANG"
            echo "Valid values for MONASCA_PERSISTER_IMPLEMENTATION_LANG are \"java\" and \"python\""
            die "Please set MONASCA_PERSISTER_IMPLEMENTATION_LANG to either \"java\" or \"python\""

        fi

        sudo systemctl enable monasca-persister

    fi
    if is_service_enabled monasca-notification; then
        install_monasca_notification
    fi

    if is_service_enabled monasca-thresh; then
        install_storm
        install_monasca_thresh
    fi

}

function update_maven {

    apt_get -y remove maven2

    apt_get -y install maven

}

function post_config_monasca {
    install_schema
}

function extra_monasca {

    install_monasca_keystone_client

    install_monasca_agent

    install_monasca_default_alarms

    if is_service_enabled horizon; then

        install_monasca_horizon_ui

        install_node_nvm

        install_go

        install_monasca_grafana

    fi

    start_monasca_services
}
function start_monasca_services {
    start_service monasca-api || restart_service monasca-api
    if is_service_enabled monasca-persister; then
        start_service monasca-persister || restart_service monasca-persister
    fi
    if is_service_enabled monasca-notification; then
        start_service monasca-notification || restart_service monasca-notification
    fi
    if is_service_enabled monasca-thresh; then
        start_service monasca-thresh || restart_service monasca-thresh
    fi
    if is_service_enabled horizon; then
        start_service grafana-server || restart_service grafana-server
    fi
    _start_monasca_agent
}

function _start_monasca_agent {
    sudo /usr/local/bin/monasca-reconfigure
    start_service monasca-agent || restart_service monasca-agent
}

function unstack_monasca {
    stop_service grafana-server || true

    stop_service monasca-agent || true

    stop_service monasca-thresh || true

    stop_service storm-supervisor || true

    stop_service storm-nimbus || true

    stop_service monasca-notification || true

    stop_service monasca-persister || true

    stop_service monasca-api || true

    stop_service kafka || true

    stop_service influxdb || true

    stop_service verticad || true

    stop_service vertica_agent || true

    stop_service cassandra || true
}

function clean_monasca {

    set +o errexit

    unstack_monasca

    if is_service_enabled horizon; then

        clean_monasca_horizon_ui

        clean_node_nvm

        clean_monasca_grafana

        clean_go

    fi

    clean_monasca_default_alarms

    clean_monasca_agent

    clean_monasca_keystone_client

    if is_service_enabled monasca-thresh; then
        clean_monasca_thresh
        clean_storm
    fi


    if is_service_enabled monasca-notification; then
        clean_monasca_notification
    fi

    if is_service_enabled monasca-persister; then
        if [[ "${MONASCA_PERSISTER_IMPLEMENTATION_LANG,,}" == 'java' ]]; then

            clean_monasca_persister_java

        elif [[ "${MONASCA_PERSISTER_IMPLEMENTATION_LANG,,}" == 'python' ]]; then

            clean_monasca_persister_python

        else

            echo "Found invalid value for varible MONASCA_PERSISTER_IMPLEMENTATION_LANG: $MONASCA_PERSISTER_IMPLEMENTATION_LANG"
            echo "Valid values for MONASCA_PERSISTER_IMPLEMENTATION_LANG are \"java\" and \"python\""
            die "Please set MONASCA_PERSISTER_IMPLEMENTATION_LANG to either \"java\" or \"python\""

        fi
    fi

    if [[ "${MONASCA_API_IMPLEMENTATION_LANG,,}" == 'java' ]]; then

        clean_monasca_api_java

    elif [[ "${MONASCA_API_IMPLEMENTATION_LANG,,}" == 'python' ]]; then

        clean_monasca_api_python

    else

        echo "Found invalid value for variable MONASCA_API_IMPLEMENTATION_LANG: $MONASCA_API_IMPLEMENTATION_LANG"
        echo "Valid values for MONASCA_API_IMPLEMENTATION_LANG are \"java\" and \"python\""
        die "Please set MONASCA_API_IMPLEMENTATION_LANG to either \"java\" or \"python\""

    fi

    clean_monasca_common

    clean_maven

    clean_schema

    clean_cli_creds

    if [[ "${MONASCA_METRICS_DB,,}" == 'influxdb' ]]; then

        clean_monasca_influxdb

    elif [[ "${MONASCA_METRICS_DB,,}" == 'vertica' ]]; then

        clean_monasca_vertica

    elif [[ "${MONASCA_METRICS_DB,,}" == 'cassandra' ]]; then

        clean_monasca_cassandra

    else

        echo "Found invalid value for variable MONASCA_METRICS_DB: $MONASCA_METRICS_DB"
        echo "Valid values for MONASCA_METRICS_DB are \"influxdb\", \"vertica\" and \"cassandra\""
        die "Please set MONASCA_METRICS_DB to either \"influxdb\", \"vertica\" or \"cassandra\""

    fi

    clean_kafka

    clean_openjdk_8_jdk

    clean_monasca_virtual_env

    #Restore errexit
    set -o errexit
}

function install_monasca_virtual_env {

    echo_summary "Install Monasca Virtual Environment"

    sudo groupadd --system monasca || true

    sudo mkdir -p /opt/monasca || true

    sudo chown $STACK_USER:monasca /opt/monasca

    (cd /opt/monasca ; virtualenv .)
}

function clean_monasca_virtual_env {

    echo_summary "Clean Monasca Virtual Environment"

    sudo rm -rf /opt/monasca

    sudo groupdel monasca

}

function install_kafka {

    echo_summary "Install Monasca Kafka"

    local kafka_tarball=kafka_${KAFKA_VERSION}.tgz
    local kafka_tarball_url=http://apache.mirrors.tds.net/kafka/${BASE_KAFKA_VERSION}/${kafka_tarball}
    local kafka_tarball_dest=${FILES}/${kafka_tarball}

    download_file ${kafka_tarball_url} ${kafka_tarball_dest}

    sudo groupadd --system kafka || true

    sudo useradd --system -g kafka kafka || true

    sudo tar -xzf ${kafka_tarball_dest} -C /opt

    sudo ln -sf /opt/kafka_${KAFKA_VERSION} /opt/kafka

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/kafka/kafka-server-start.sh /opt/kafka_${KAFKA_VERSION}/bin/kafka-server-start.sh

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/kafka/kafka.service /etc/systemd/system/kafka.service

    sudo chown root:root /etc/systemd/system/kafka.service

    sudo chmod 644 /etc/systemd/system/kafka.service

    sudo mkdir -p /var/kafka || true

    sudo chown kafka:kafka /var/kafka

    sudo chmod 755 /var/kafka

    sudo rm -rf /var/kafka/lost+found

    sudo mkdir -p /var/log/kafka || true

    sudo chown kafka:kafka /var/log/kafka

    sudo chmod 755 /var/log/kafka

    sudo ln -sf /opt/kafka/config /etc/kafka

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/kafka/log4j.properties /etc/kafka/log4j.properties

    sudo chown kafka:kafka /etc/kafka/log4j.properties

    sudo chmod 644 /etc/kafka/log4j.properties

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/kafka/server.properties /etc/kafka/server.properties

    sudo chown kafka:kafka /etc/kafka/server.properties

    sudo chmod 644 /etc/kafka/server.properties

    sudo systemctl enable kafka

    sudo systemctl start kafka || sudo systemctl restart kafka

}

function clean_kafka {

    echo_summary "Clean Monasca Kafka"

    sudo rm -rf /var/kafka

    sudo rm -rf /var/log/kafka

    sudo rm -rf /etc/kafka

    sudo rm -rf /opt/kafka

    sudo systemctl disable kafka

    sudo rm -rf /etc/systemd/system/kafka.service

    sudo userdel kafka

    sudo groupdel kafka

    sudo rm -rf /opt/kafka_${KAFKA_VERSION}

    sudo rm -rf ${FILES}/kafka_${KAFKA_VERSION}.tgz

}

function install_monasca_influxdb {

    echo_summary "Install Monasca Influxdb"

    local influxdb_deb=influxdb_${INFLUXDB_VERSION}_amd64.deb
    local influxdb_deb_url=https://dl.influxdata.com/influxdb/releases/${influxdb_deb}
    local influxdb_deb_dest=${FILES}/${influxdb_deb}

    download_file ${influxdb_deb_url} ${influxdb_deb_dest}

    sudo dpkg --skip-same-version -i ${influxdb_deb_dest}

    # Validate INFLUXDB_VERSION
    validate_version ${INFLUXDB_VERSION}

    if [[ $? -ne 0 ]]; then
        echo "Found invalid value for variable INFLUXDB_VERSION: $INFLUXDB_VERSION"
        echo "Valid values for INFLUXDB_VERSION must be in the form of 1.0.0"
        die "Please set INFLUXDB_VERSION to a correct value"
    fi

    # In InfluxDB v1.0.0 the config options cluster, collectd and opentsdb changed. As a result
    # a different config file is deployed. See,
    # https://github.com/influxdata/influxdb/blob/master/CHANGELOG.md#v100-2016-09-08, for more details.
    retval=$(compare_versions ${INFLUXDB_VERSION} "1.0.0")
    if [[ "$retval" == "lt" ]]; then
        sudo cp -f "${MONASCA_API_DIR}"/devstack/files/influxdb/influxdb.conf /etc/influxdb/influxdb.conf
    else
        sudo cp -f "${MONASCA_API_DIR}"/devstack/files/influxdb/influxdb-1.0.0.conf /etc/influxdb/influxdb.conf
    fi

    if [[ ${SERVICE_HOST} ]]; then

        # set influxdb server listening ip address
        sudo sed -i "s/hostname = \"127\.0\.0\.1\"/hostname = \"${SERVICE_HOST}\"/g" /etc/influxdb/influxdb.conf

    fi

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/influxdb/influxdb /etc/default/influxdb

    sudo systemctl start influxdb || sudo systemctl restart influxdb

}

function install_monasca_vertica {

    echo_summary "Install Monasca Vertica"

    apt_get -y install dialog

    sudo dpkg --skip-same-version -i /vagrant_home/vertica_${VERTICA_VERSION}_amd64.deb

    # Download Vertica JDBC driver
    # local vertica_jar=vertica-jdbc-${VERTICA_VERSION}.jar
    # local vertica_jar_url=https://my.vertica.com/client_drivers/7.2.x/${VERTICA_VERSION}/${vertica_jar}
    # local vertica_jar_dest=${FILES}/${vertica_jar}
    #
    # download_file ${vertica_jar_url} ${vertica_jar_dest}

    # Current version of Vertica 8.0.0 doesn't support Ubuntu Xenial, so fake a version
    sudo cp -p /etc/debian_version /etc/debian_version.org
    sudo sh -c "echo 'jessie/sid' > /etc/debian_version"

    sudo /opt/vertica/sbin/install_vertica --hosts "127.0.0.1" --deb /vagrant_home/vertica_${VERTICA_VERSION}_amd64.deb --dba-user-password password --license CE --accept-eula --failure-threshold NONE

    sudo su dbadmin -c '/opt/vertica/bin/admintools -t create_db -s "127.0.0.1" -d mon -p password'

    # Bring back Ubuntu version
    sudo mv /etc/debian_version.org /etc/debian_version

    /opt/vertica/bin/vsql -U dbadmin -w password < "${MONASCA_API_DIR}"/devstack/files/vertica/mon_metrics.sql

    /opt/vertica/bin/vsql -U dbadmin -w password < "${MONASCA_API_DIR}"/devstack/files/vertica/mon_alarms.sql

    /opt/vertica/bin/vsql -U dbadmin -w password < "${MONASCA_API_DIR}"/devstack/files/vertica/roles.sql

    /opt/vertica/bin/vsql -U dbadmin -w password < "${MONASCA_API_DIR}"/devstack/files/vertica/users.sql

    # Copy Vertica JDBC driver to /opt/monasca
    # sudo cp ${FILES}/vertica-jdbc-${VERTICA_VERSION}.jar /opt/monasca/vertica-jdbc-${VERTICA_VERSION}.jar
    sudo cp /vagrant_home/vertica-jdbc-${VERTICA_VERSION}.jar /opt/monasca/vertica-jdbc-${VERTICA_VERSION}.jar

}

function install_monasca_cassandra {

    echo_summary "Install Monasca Cassandra"

    if [[ "$OFFLINE" != "True" ]]; then
        sudo sh -c "echo 'deb http://www.apache.org/dist/cassandra/debian ${CASSANDRA_VERSION} main' > /etc/apt/sources.list.d/cassandra.list"
        REPOS_UPDATED=False
        PUBLIC_KEY=`apt_get_update 2>&1 | awk '/NO_PUBKEY/ {print $21}'`
        gpg --keyserver pgp.mit.edu --recv-keys ${PUBLIC_KEY}
        gpg --export --armor ${PUBLIC_KEY} | sudo apt-key --keyring /etc/apt/trusted.gpg.d/cassandra.gpg add -
    fi

    REPOS_UPDATED=False
    apt_get_update
    apt_get -y install cassandra

    if [[ ${SERVICE_HOST} ]]; then

        # set cassandra server listening ip address
        sudo sed -i "s/^rpc_address: localhost/rpc_address: ${SERVICE_HOST}/g" /etc/cassandra/cassandra.yaml

    fi

    # set batch size larger
    sudo sed -i "s/^batch_size_warn_threshold_in_kb: 5/batch_size_warn_threshold_in_kb: 50/g" /etc/cassandra/cassandra.yaml

    sudo sed -i "s/^batch_size_fail_threshold_in_kb: 50/batch_size_fail_threshold_in_kb: 500/g" /etc/cassandra/cassandra.yaml

    sudo service cassandra restart

    echo "Sleep for 15 seconds to wait starting up Cassandra"
    sleep 15s

    export CQLSH_NO_BUNDLED=true
    pip_install 'cassandra-driver>=2.1.4,!=3.6.0'

    if [[ ${SERVICE_HOST} ]]; then

        /usr/bin/cqlsh ${SERVICE_HOST} -f "${MONASCA_API_DIR}"/devstack/files/cassandra/cassandra_schema.cql

    else

        /usr/bin/cqlsh -f "${MONASCA_API_DIR}"/devstack/files/cassandra/cassandra_schema.cql

    fi

}

function clean_monasca_influxdb {

    echo_summary "Clean Monasca Influxdb"

    sudo rm -f /etc/default/influxdb

    sudo rm -f /etc/influxdb/influxdb.conf

    sudo dpkg --purge influxdb

    sudo rm -rf /var/log/influxdb

    sudo rm -rf /tmp/influxdb

    sudo rm -rf /var/lib/influxdb

    sudo rm -rf /etc/init.d/influxdb

    sudo rm -rf /opt/staging/influxdb/influxdb-package

    sudo rm -rf /etc/influxdb

    sudo rm -rf /tmp/bootstrap*

    sudo rm -rf /run/influxdb

    sudo rm -f  ${FILES}/influxdb_${INFLUXDB_VERSION}_amd64.deb

    sudo rm -f /etc/init.d/influxdb
}

function clean_monasca_vertica {

    echo_summary "Clean Monasca Vertica"

    sudo rm -rf /opt/vertica

    sudo dpkg --purge vertica

    sudo userdel dbadmin

    sudo groupdel verticadba

    sudo rm -rf /home/dbadmin

    apt_get -y purge dialog
}

function clean_monasca_cassandra {

    echo_summary "Clean Monasca Cassandra"

    sudo rm -f /etc/cassandra/cassandra.yaml

    sudo rm -rf /var/log/cassandra

    sudo rm -rf /etc/cassandra

    apt_get -y purge cassandra

    apt_get -y autoremove

    sudo rm -f /etc/apt/sources.list.d/cassandra.list

    sudo rm -f /etc/apt/trusted.gpg.d/cassandra.gpg
}

function install_cli_creds {

    echo_summary "Install Monasca CLI Creds"

    if [[ "${MONASCA_METRICS_DB,,}" == 'cassandra' ]]; then

        sudo sh -c "cat ${MONASCA_API_DIR}/devstack/files/env.sh \
                        ${MONASCA_API_DIR}/devstack/files/cassandra/env_cassandra.sh \
                        > /etc/profile.d/monasca_cli.sh"

    else

        sudo cp -f "${MONASCA_API_DIR}"/devstack/files/env.sh /etc/profile.d/monasca_cli.sh

    fi

    if [[ ${SERVICE_HOST} ]]; then

        sudo sed -i "s/127\.0\.0\.1/${SERVICE_HOST}/g" /etc/profile.d/monasca_cli.sh

    fi

    sudo chown root:root /etc/profile.d/monasca_cli.sh

    sudo chmod 0644 /etc/profile.d/monasca_cli.sh

}

function clean_cli_creds {

    echo_summary "Clean Monasca CLI Creds"

    sudo rm -f /etc/profile.d/monasca_cli.sh

}

function install_schema {

    echo_summary "Install Monasca Schema"

    sudo mkdir -p /opt/monasca/sqls || true

    sudo chmod 0755 /opt/monasca/sqls

    if [[ "${MONASCA_METRICS_DB,,}" == 'influxdb' ]]; then

        sudo cp -f "${MONASCA_API_DIR}"/devstack/files/schema/influxdb_setup.py /opt/monasca/influxdb_setup.py

        sudo chmod 0750 /opt/monasca/influxdb_setup.py

        sudo chown root:root /opt/monasca/influxdb_setup.py

        sudo /opt/monasca/influxdb_setup.py

    fi

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/schema/mon_mysql.sql /opt/monasca/sqls/mon.sql
    sudo chmod 0644 /opt/monasca/sqls/mon.sql
    sudo chown root:root /opt/monasca/sqls/mon.sql

    recreate_database mon
    recreate_users mon MON_DB_USERS MON_DB_HOSTS
    mysql -u$DATABASE_USER -p$DATABASE_PASSWORD -h$MYSQL_HOST < /opt/monasca/sqls/mon.sql || echo "Did the schema change? This process will fail on schema changes."

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/schema/winchester.sql /opt/monasca/sqls/winchester.sql

    sudo chmod 0644 /opt/monasca/sqls/winchester.sql

    sudo chown root:root /opt/monasca/sqls/winchester.sql

    # must login as root@localhost
    mysql -u$DATABASE_USER -p$DATABASE_PASSWORD -h$MYSQL_HOST < /opt/monasca/sqls/winchester.sql || echo "Did the schema change? This process will fail on schema changes."

    sudo mkdir -p /opt/kafka/logs || true

    sudo chown kafka:kafka /opt/kafka/logs

    sudo chmod 0766 /opt/kafka/logs

    /opt/kafka/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 64 --topic metrics
    /opt/kafka/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 12 --topic events
    /opt/kafka/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 12 --topic alarm-state-transitions
    /opt/kafka/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 12 --topic alarm-notifications
    /opt/kafka/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 3 --topic retry-notifications
    /opt/kafka/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 3 --topic 60-seconds-notifications

}

function clean_schema {

    echo_summary "Clean Monasca Schema"

    sudo echo "drop database winchester;" | mysql -u$DATABASE_USER -p$DATABASE_PASSWORD

    sudo echo "drop database mon;" | mysql -u$DATABASE_USER -p$DATABASE_PASSWORD

    sudo rm -f /opt/monasca/sqls/winchester.sql

    sudo rm -f /opt/monasca/sqls/mon.sql

    sudo rm -f /opt/monasca/influxdb_setup.py

    sudo rm -rf /opt/monasca/sqls

}

function install_openjdk_8_jdk {

    echo_summary "Install Monasca openjdk_8_jdk"

    apt_get -y install openjdk-8-jdk

}

function clean_openjdk_8_jdk {

    echo_summary "Clean Monasca openjdk_8_jdk"

    apt_get -y purge openjdk-8-jdk

    apt_get -y autoremove

}

function install_maven {

    echo_summary "Install Monasca Maven"

    apt_get -y install maven

}

function clean_maven {

    echo_summary "Clean Monasca Maven"

    apt_get -y purge maven
}

function install_git {

    echo_summary "Install git"

    apt_get -y install git

}

function download_monasca_libraries {

    echo_summary "Download Monasca monasca_common and monasca_statsd"
  
    GIT_DEPTH_OLD=$GIT_DEPTH
    GIT_DEPTH=0
    git_clone $MONASCA_COMMON_REPO $MONASCA_COMMON_DIR $MONASCA_COMMON_BRANCH
    git_clone $MONASCA_STATSD_REPO $MONASCA_STATSD_DIR $MONASCA_STATSD_BRANCH

    (cd "${MONASCA_COMMON_DIR}"/java ; sudo mvn clean install -DskipTests)

    (cd "${MONASCA_COMMON_DIR}"; python setup.py sdist)
    MONASCA_COMMON_SRC_DIST=$(ls -td "$MONASCA_COMMON_DIR"/dist/monasca-common*.tar.gz | head -1)

    (cd "${MONASCA_STATSD_DIR}"; python setup.py sdist)
    MONASCA_STATSD_SRC_DIST=$(ls -td "$MONASCA_STATSD_DIR"/dist/monasca-statsd*.tar.gz | head -1)

    GIT_DEPTH=$GIT_DEPTH_OLD
}

function clean_monasca_common {

    echo_summary "Clean Monasca monasca_common"

    (cd "${MONASCA_COMMON_DIR}" ; sudo mvn clean)

}

function install_monasca_api_java {

    echo_summary "Install Monasca monasca_api_java"

    (cd "${MONASCA_API_DIR}"/java ; sudo mvn clean package -DskipTests)

    local version="$(get_version_from_pom "${MONASCA_API_DIR}"/java)"

    sudo cp -f "${MONASCA_API_DIR}"/java/target/monasca-api-${version}-shaded.jar \
      /opt/monasca/monasca-api.jar

    sudo useradd --system -g monasca mon-api || true

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-api/monasca-api.service /etc/systemd/system/monasca-api.service

    if [[ "${MONASCA_METRICS_DB,,}" == 'vertica' ]]; then

        # Add the Vertica JDBC to the class path.
        sudo sed -i "s/-cp \/opt\/monasca\/monasca-api.jar/-cp \/opt\/monasca\/monasca-api.jar:\/opt\/monasca\/vertica-jdbc-${VERTICA_VERSION}.jar/g" /etc/systemd/system/monasca-api.service

        sudo sed -i "s/influxdb.service/vertica.service/g" /etc/systemd/system/monasca-api.service

    fi

    sudo chown root:root /etc/systemd/system/monasca-api.service

    sudo chmod 0644 /etc/systemd/system/monasca-api.service

    sudo mkdir -p /var/log/monasca || true

    sudo chown root:monasca /var/log/monasca

    sudo chmod 0755 /var/log/monasca

    sudo mkdir -p /var/log/monasca/api || true

    sudo chown root:monasca /var/log/monasca/api

    sudo chmod 0775 /var/log/monasca/api

    sudo mkdir -p /etc/monasca || true

    sudo chown root:monasca /etc/monasca

    sudo chmod 0775 /etc/monasca

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-api/api-config.yml /etc/monasca/api-config.yml

    if [[ "${MONASCA_METRICS_DB,,}" == 'vertica' ]]; then

        # Switch databaseType from influxdb to vertica
        sudo sed -i "s/databaseType: \"influxdb\"/databaseType: \"vertica\"/g" /etc/monasca/api-config.yml

    fi

    sudo chown mon-api:root /etc/monasca/api-config.yml

    sudo chmod 0640 /etc/monasca/api-config.yml

    if [[ ${SERVICE_HOST} ]]; then

        if [[ "${MONASCA_METRICS_DB,,}" == 'influxdb' ]]; then

            # set influxdb ip address
            sudo sed -i "s/url: \"http:\/\/127\.0\.0\.1:8086\"/url: \"http:\/\/${SERVICE_HOST}:8086\"/g" /etc/monasca/api-config.yml

        fi

        # set kafka ip address
        sudo sed -i "s/127\.0\.0\.1:9092/${SERVICE_HOST}:9092/g" /etc/monasca/api-config.yml
        # set monasca api server listening ip address
        sudo sed -i "s/bindHost: 127\.0\.0\.1/bindHost: ${SERVICE_HOST}/g" /etc/monasca/api-config.yml
        # set mysql ip address
        sudo sed -i "s/127\.0\.0\.1:3306/${SERVICE_HOST}:3306/g" /etc/monasca/api-config.yml

    fi

}

function install_monasca_api_python {

    echo_summary "Install Monasca monasca_api_python"

    apt_get -y install python-dev
    apt_get -y install libmysqlclient-dev

    sudo mkdir -p /opt/monasca-api

    sudo chown $STACK_USER:monasca /opt/monasca-api

    (cd /opt/monasca-api; virtualenv .)

    PIP_VIRTUAL_ENV=/opt/monasca-api

    (cd /opt/monasca-api ; sudo ./bin/pip install $MONASCA_COMMON_SRC_DIST)

    (cd /opt/monasca-api ; sudo ./bin/pip install $MONASCA_STATSD_SRC_DIST)

    pip_install gunicorn
    pip_install PyMySQL
    if [[ "${MONASCA_METRICS_DB,,}" == 'influxdb' ]]; then

        pip_install influxdb==2.8.0

    elif [[ "${MONASCA_METRICS_DB,,}" == 'cassandra' ]]; then

        pip_install 'cassandra-driver>=2.1.4,!=3.6.0'

    fi

    (cd "${MONASCA_API_DIR}" ; sudo python setup.py sdist)
    MONASCA_API_SRC_DIST=$(ls -td "${MONASCA_API_DIR}"/dist/monasca-api-*.tar.gz)

    (cd /opt/monasca-api ; ./bin/pip install $MONASCA_API_SRC_DIST)

    unset PIP_VIRTUAL_ENV

    sudo useradd --system -g monasca mon-api || true

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-api/python/monasca-api.service /etc/systemd/system/monasca-api.service

    if [[ "${MONASCA_METRICS_DB,,}" == 'cassandra' ]]; then

        sudo sed -i "s/influxdb.service/cassandra.service/g" /etc/systemd/system/monasca-api.service

    fi

    sudo chown root:root /etc/systemd/system/monasca-api.service

    sudo chmod 0644 /etc/systemd/system/monasca-api.service

    sudo mkdir -p /var/log/monasca || true

    sudo chown root:monasca /var/log/monasca

    sudo chmod 0755 /var/log/monasca

    sudo mkdir -p /var/log/monasca/api || true

    sudo chown root:monasca /var/log/monasca/api

    sudo chmod 0775 /var/log/monasca/api

    sudo mkdir -p /etc/monasca || true

    sudo chown root:monasca /etc/monasca

    sudo chmod 0775 /etc/monasca

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-api/python/api-config.conf /etc/monasca/api-config.conf

    sudo chown mon-api:root /etc/monasca/api-config.conf

    sudo chmod 0660 /etc/monasca/api-config.conf

    if [[ ${SERVICE_HOST} ]]; then

        # set influxdb ip address
        sudo sed -i "s/ip_address = 127\.0\.0\.1/ip_address = ${SERVICE_HOST}/g" /etc/monasca/api-config.conf
        # set kafka ip address
        sudo sed -i "s/127\.0\.0\.1:9092/${SERVICE_HOST}:9092/g" /etc/monasca/api-config.conf
        # set mysql ip address
        sudo sed -i "s/hostname = 127\.0\.0\.1/hostname = ${SERVICE_HOST}/g" /etc/monasca/api-config.conf
        # set keystone ip address
        sudo sed -i "s/identity_uri = http:\/\/127\.0\.0\.1:35357/identity_uri = http:\/\/${SERVICE_HOST}:35357/g" /etc/monasca/api-config.conf
        # set cassandra ip address
        sudo sed -i "s/cluster_ip_addresses: 127\.0\.0\.1/cluster_ip_addresses: ${SERVICE_HOST}/g" /etc/monasca/api-config.conf

    fi

    if [[ "${MONASCA_METRICS_DB,,}" == 'cassandra' ]]; then

        # Switch databaseType from influxdb to cassandra
        sudo sed -i "s/metrics_driver = monasca_api\.common\.repositories\.influxdb/#metrics_driver = monasca_api.common.repositories.influxdb/g" /etc/monasca/api-config.conf
        sudo sed -i "s/#metrics_driver = monasca_api\.common\.repositories\.cassandra/metrics_driver = monasca_api.common.repositories.cassandra/g" /etc/monasca/api-config.conf

    fi

    sudo ln -sf /etc/monasca/api-config.conf /etc/api-config.conf

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-api/python/api-config.ini /etc/monasca/api-config.ini

    sudo chown mon-api:root /etc/monasca/api-config.ini

    sudo chmod 0660 /etc/monasca/api-config.ini

    if [[ ${SERVICE_HOST} ]]; then

        # set monasca api server listening ip address
        sudo sed -i "s/host = 127\.0\.0\.1/host = ${SERVICE_HOST}/g"  /etc/monasca/api-config.ini

    fi

    sudo ln -sf /etc/monasca/api-config.ini /etc/api-config.ini

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-api/python/api-logging.conf /etc/monasca/api-logging.conf

    sudo chown mon-api:root /etc/monasca/api-logging.conf

    sudo chmod 0660 /etc/monasca/api-logging.conf

    sudo ln -sf /etc/monasca/api-logging.conf /etc/api-logging.conf

}

function clean_monasca_api_java {

    echo_summary "Clean Monasca monasca_api_java"

    (cd "${MONASCA_API_DIR}" ; sudo mvn clean)

    sudo rm /etc/monasca/api-config.yml

    sudo rm -rf /var/log/monasca/api

    sudo systemctl disable monasca-api

    sudo rm /etc/systemd/system/monasca-api.service

    sudo rm /opt/monasca/monasca-api.jar

    sudo rm /var/log/upstart/monasca-api.log*

    sudo userdel mon-api
}

function clean_monasca_api_python {

    echo_summary "Clean Monasca monasca_api_python"

    sudo systemctl disable monasca-api

    sudo rm /etc/systemd/system/monasca-api.service

    sudo rm /etc/api-config.conf

    sudo rm /etc/monasca/api-config.conf

    sudo rm /etc/api-logging.conf

    sudo rm /etc/monasca/api-logging.conf

    sudo rm /etc/api-config.ini

    sudo rm /etc/monasca/api-config.ini

    sudo rm -rf /var/log/monasca/api

    sudo rm /var/log/upstart/monasca-api.log*

    sudo rm -rf /opt/monasca-api

    sudo userdel mon-api

}

function install_monasca_persister_java {

    echo_summary "Install Monasca monasca_persister_java"

    git_clone $MONASCA_PERSISTER_REPO $MONASCA_PERSISTER_DIR $MONASCA_PERSISTER_BRANCH
    (cd "${MONASCA_PERSISTER_DIR}"/java ; sudo mvn clean package -DskipTests)

    local version="$(get_version_from_pom "${MONASCA_PERSISTER_DIR}"/java)"

    sudo cp -f "${MONASCA_PERSISTER_DIR}"/java/target/monasca-persister-${version}-shaded.jar \
      /opt/monasca/monasca-persister.jar

    sudo useradd --system -g monasca mon-persister || true

    sudo mkdir -p /var/log/monasca || true

    sudo chown root:monasca /var/log/monasca

    sudo chmod 0755 /var/log/monasca

    sudo mkdir -p /var/log/monasca/persister || true

    sudo chown root:monasca /var/log/monasca/persister

    sudo chmod 0775 /var/log/monasca/persister

    sudo mkdir -p /etc/monasca || true

    sudo chown root:monasca /etc/monasca

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-persister/persister-config.yml /etc/monasca/persister-config.yml

    sudo chown mon-persister:monasca /etc/monasca/persister-config.yml

    sudo chmod 0640 /etc/monasca/persister-config.yml

    if [[ "${MONASCA_METRICS_DB,,}" == 'vertica' ]]; then

        # Switch databaseType from influxdb to vertica
        sudo sed -i "s/databaseType: influxdb/databaseType: vertica/g" /etc/monasca/persister-config.yml

    fi

    if [[ ${SERVICE_HOST} ]]; then

        # set influxdb ip address
        sudo sed -i "s/url: \"http:\/\/127\.0\.0\.1:8086\"/url: \"http:\/\/${SERVICE_HOST}:8086\"/g" /etc/monasca/persister-config.yml
        # set monasca persister server listening ip address
        sudo sed -i "s/bindHost: 127\.0\.0\.1/bindHost: ${SERVICE_HOST}/g" /etc/monasca/persister-config.yml

    fi

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-persister/monasca-persister.service /etc/systemd/system/monasca-persister.service

    if [[ "${MONASCA_METRICS_DB,,}" == 'vertica' ]]; then

        # Add the Vertica JDBC to the class path.
        sudo sed -i "s/-cp \/opt\/monasca\/monasca-persister.jar/-cp \/opt\/monasca\/monasca-persister.jar:\/opt\/monasca\/vertica-jdbc-${VERTICA_VERSION}.jar/g" /etc/systemd/system/monasca-persister.service

        sudo sed -i "s/influxdb.service/vertica.service/g" /etc/systemd/system/monasca-persister.service

    fi

    sudo chown root:root /etc/systemd/system/monasca-persister.service

    sudo chmod 0644 /etc/systemd/system/monasca-persister.service

}

function install_monasca_persister_python {

    echo_summary "Install Monasca monasca_persister_python"

    git_clone $MONASCA_PERSISTER_REPO $MONASCA_PERSISTER_DIR $MONASCA_PERSISTER_BRANCH
    (cd "${MONASCA_PERSISTER_DIR}"; sudo python setup.py sdist)

    MONASCA_PERSISTER_SRC_DIST=$(ls -td "${MONASCA_PERSISTER_DIR}"/dist/monasca-persister-*.tar.gz | head -1)

    sudo mkdir -p /opt/monasca-persister || true

    sudo chown $STACK_USER:monasca /opt/monasca-persister

    (cd /opt/monasca-persister ; virtualenv .)

    PIP_VIRTUAL_ENV=/opt/monasca-persister

    (cd /opt/monasca-persister ; sudo ./bin/pip install $MONASCA_COMMON_SRC_DIST)

    (cd /opt/monasca-persister ; ./bin/pip install $MONASCA_PERSISTER_SRC_DIST)

    if [[ "${MONASCA_METRICS_DB,,}" == 'influxdb' ]]; then

        pip_install influxdb==2.8.0

    elif [[ "${MONASCA_METRICS_DB,,}" == 'cassandra' ]]; then

        pip_install 'cassandra-driver>=2.1.4,!=3.6.0'

    fi

    unset PIP_VIRTUAL_ENV

    sudo useradd --system -g monasca mon-persister || true

    sudo mkdir -p /var/log/monasca || true

    sudo chown root:monasca /var/log/monasca

    sudo chmod 0755 /var/log/monasca

    sudo mkdir -p /var/log/monasca/persister || true

    sudo chown root:monasca /var/log/monasca/persister

    sudo chmod 0775 /var/log/monasca/persister

    sudo mkdir -p /etc/monasca || true

    sudo chown root:monasca /etc/monasca

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-persister/python/persister.conf /etc/monasca/persister.conf
    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-persister/python/persister-logging.conf /etc/monasca/persister-logging.conf

    sudo chown mon-persister:monasca /etc/monasca/persister.conf

    sudo chmod 0640 /etc/monasca/persister.conf

    if [[ ${SERVICE_HOST} ]]; then

        # set kafka ip address
        sudo sed -i "s/uri = 127\.0\.0\.1:9092/uri = ${SERVICE_HOST}:9092/g" /etc/monasca/persister.conf
        # set influxdb ip address
        sudo sed -i "s/ip_address = 127\.0\.0\.1/ip_address = ${SERVICE_HOST}/g" /etc/monasca/persister.conf
        # set cassandra ip address
        sudo sed -i "s/cluster_ip_addresses: 127\.0\.0\.1/cluster_ip_addresses: ${SERVICE_HOST}/g" /etc/monasca/persister.conf

    fi

    if [[ "${MONASCA_METRICS_DB,,}" == 'cassandra' ]]; then

        # Switch databaseType from influxdb to cassandra
        sudo sed -i "s/metrics_driver = monasca_persister\.repositories\.influxdb/#metrics_driver = monasca_persister.repositories.influxdb/g" /etc/monasca/persister.conf
        sudo sed -i "s/#metrics_driver = monasca_persister\.repositories\.cassandra/metrics_driver = monasca_persister.repositories.cassandra/g" /etc/monasca/persister.conf
        sudo sed -i "s/alarm_state_history_driver = monasca_persister\.repositories\.influxdb/#alarm_state_history_driver = monasca_persister.repositories.influxdb/g" /etc/monasca/persister.conf
        sudo sed -i "s/#alarm_state_history_driver = monasca_persister\.repositories\.cassandra/alarm_state_history_driver = monasca_persister.repositories.cassandra/g" /etc/monasca/persister.conf

    fi

    # /etc/monasca/persister-config.yml is needed for the Monasca Agent configuration.
    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-persister/persister-config.yml /etc/monasca/persister-config.yml

    sudo chown mon-persister:monasca /etc/monasca/persister-config.yml

    sudo chmod 0640 /etc/monasca/persister-config.yml

    if [[ ${SERVICE_HOST} ]]; then

        # set influxdb ip address
        sudo sed -i "s/url: \"http:\/\/127\.0\.0\.1:8086\"/url: \"http:\/\/${SERVICE_HOST}:8086\"/g" /etc/monasca/persister-config.yml
        # set monasca persister server listening ip address
        sudo sed -i "s/bindHost: 127\.0\.0\.1/bindHost: ${SERVICE_HOST}/g" /etc/monasca/persister-config.yml

    fi

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-persister/python/monasca-persister.service /etc/systemd/system/monasca-persister.service

    if [[ "${MONASCA_METRICS_DB,,}" == 'cassandra' ]]; then

        sudo sed -i "s/influxdb.service/cassandra.service/g" /etc/systemd/system/monasca-persister.service

    fi

    sudo chown root:root /etc/systemd/system/monasca-persister.service

    sudo chmod 0644 /etc/systemd/system/monasca-persister.service

}

function clean_monasca_persister_java {

    echo_summary "Clean Monasca monasca_persister_java"

    (cd "${MONASCA_PERSISTER_DIR}" ; sudo mvn clean)

    sudo systemctl disable monasca-persister

    sudo rm /etc/systemd/system/monasca-persister.service

    sudo rm /etc/monasca/persister-config.yml

    sudo rm -rf /var/log/monasca/persister

    sudo rm /opt/monasca/monasca-persister.jar

    sudo rm /var/log/upstart/monasca-persister.log*

    sudo userdel mon-persister
}

function clean_monasca_persister_python {

    echo_summary "Clean Monasca monasca_persister_python"

    sudo systemctl disable monasca-persister

    sudo rm /etc/systemd/system/monasca-persister.service

    sudo rm /etc/monasca/persister.conf
    sudo rm /etc/monasca/persister-logging.conf

    sudo rm /etc/monasca/persister-config.yml

    sudo rm -rf /var/log/monasca/persister

    sudo rm /var/log/upstart/monasca-persister.log*

    sudo rm -rf /opt/monasca-persister

    sudo userdel mon-persister
}

function install_monasca_notification {

    echo_summary "Install Monasca monasca_notification"

    apt_get -y install python-dev
    apt_get -y install build-essential
    apt_get -y install python-mysqldb
    apt_get -y install libmysqlclient-dev

    git_clone $MONASCA_NOTIFICATION_REPO $MONASCA_NOTIFICATION_DIR $MONASCA_NOTIFICATION_BRANCH
    (cd "${MONASCA_NOTIFICATION_DIR}" ; sudo python setup.py sdist)

    MONASCA_NOTIFICATION_SRC_DIST=$(ls -td "${MONASCA_NOTIFICATION_DIR}"/dist/monasca-notification-*.tar.gz | head -1)

    PIP_VIRTUAL_ENV=/opt/monasca

    (cd /opt/monasca ; sudo ./bin/pip install $MONASCA_COMMON_SRC_DIST)

    (cd /opt/monasca ; sudo ./bin/pip install $MONASCA_STATSD_SRC_DIST)

    (cd /opt/monasca ; ./bin/pip install $MONASCA_NOTIFICATION_SRC_DIST)

    unset PIP_VIRTUAL_ENV

    sudo useradd --system -g monasca mon-notification || true

    sudo mkdir -p /var/log/monasca/notification || true

    sudo chown root:monasca /var/log/monasca/notification

    sudo chmod 0775 /var/log/monasca/notification

    sudo mkdir -p /etc/monasca || true

    sudo chown root:monasca /etc/monasca

    sudo chmod 0775 /etc/monasca

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-notification/notification.yaml /etc/monasca/notification.yaml

    sudo chown mon-notification:monasca /etc/monasca/notification.yaml

    sudo chmod 0660 /etc/monasca/notification.yaml

     if [[ ${SERVICE_HOST} ]]; then

        # set kafka ip address
        sudo sed -i "s/url: \"127\.0\.0\.1:9092\"/url: \"${SERVICE_HOST}:9092\"/g" /etc/monasca/notification.yaml
        # set mysql ip address
        sudo sed -i "s/host: \"127\.0\.0\.1\"/host: \"${SERVICE_HOST}\"/g" /etc/monasca/notification.yaml

    fi

    sudo sed -e "
       s|%MONASCA_STATSD_PORT%|$MONASCA_STATSD_PORT|g;
    " -i /etc/monasca/notification.yaml

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-notification/monasca-notification.service /etc/systemd/system/monasca-notification.service

    sudo chown root:root /etc/systemd/system/monasca-notification.service

    sudo chmod 0644 /etc/systemd/system/monasca-notification.service

    sudo systemctl enable monasca-notification

    sudo debconf-set-selections <<< "postfix postfix/mailname string localhost"

    sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Local only'"

    apt_get -y install mailutils

}

function clean_monasca_notification {

    echo_summary "Clean Monasca monasca_notification"

    sudo systemctl disable monasca-notification

    sudo rm /etc/systemd/system/monasca-notification.service

    sudo rm /etc/monasca/notification.yaml

    sudo rm -rf /var/log/monasca/notification

    sudo userdel mon-notification

    sudo rm -rf /opt/monasca/monasca-notification

    sudo rm /var/log/upstart/monasca-notification.log*

    apt_get -y purge libmysqlclient-dev
    apt_get -y purge python-mysqldb
    apt_get -y purge build-essential
    apt_get -y purge python-dev

    apt_get -y purge mailutils

}

function install_storm {

    echo_summary "Install Monasca Storm"

    local storm_tarball=apache-storm-${STORM_VERSION}.tar.gz
    local storm_tarball_url=http://apache.mirrors.tds.net/storm/apache-storm-${STORM_VERSION}/${storm_tarball}
    local storm_tarball_dest=${FILES}/${storm_tarball}

    download_file ${storm_tarball_url} ${storm_tarball_dest}

    sudo groupadd --system storm || true

    sudo useradd --system -g storm storm || true

    sudo mkdir -p /opt/storm || true

    sudo chown storm:storm /opt/storm

    sudo chmod 0755 /opt/storm

    sudo tar -xzf ${storm_tarball_dest} -C /opt/storm

    sudo ln -sf /opt/storm/apache-storm-${STORM_VERSION} /opt/storm/current

    sudo mkdir /var/storm || true

    sudo chown storm:storm /var/storm

    sudo chmod 0775 /var/storm

    sudo mkdir /var/log/storm || true

    sudo chown storm:storm /var/log/storm

    sudo chmod 0775 /var/log/storm

    sudo ln -sf /var/log/storm /opt/storm/current/logs

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/storm/storm.yaml /opt/storm/apache-storm-${STORM_VERSION}/conf/storm.yaml

    sudo chown storm:storm /opt/storm/apache-storm-${STORM_VERSION}/conf/storm.yaml

    sudo chmod 0644 /opt/storm/apache-storm-${STORM_VERSION}/conf/storm.yaml

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/storm/storm-nimbus.service /etc/systemd/system/storm-nimbus.service

    sudo chown root:root /etc/systemd/system/storm-nimbus.service

    sudo chmod 0644 /etc/systemd/system/storm-nimbus.service

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/storm/storm-supervisor.service /etc/systemd/system/storm-supervisor.service

    sudo chown root:root /etc/systemd/system/storm-supervisor.service

    sudo chmod 0644 /etc/systemd/system/storm-supervisor.service

    sudo systemctl enable storm-nimbus

    sudo systemctl enable storm-supervisor

    sudo systemctl start storm-nimbus || sudo systemctl restart storm-nimbus

    sudo systemctl start storm-supervisor || sudo systemctl restart storm-supervisor

}

function clean_storm {

    echo_summary "Clean Monasca Storm"

    sudo systemctl disable storm-supervisor

    sudo systemctl disable storm-nimbus

    sudo rm /etc/systemd/system/storm-supervisor.service

    sudo rm /etc/systemd/system/storm-nimbus.service

    sudo rm /opt/storm/apache-storm-${STORM_VERSION}/conf/storm.yaml

    sudo unlink /opt/storm/current/logs

    sudo rm -rf /var/storm

    sudo rm -rf /var/log/storm

    sudo userdel storm || true

    sudo groupdel storm || true

    sudo unlink /opt/storm/current

    sudo rm -rf /opt/storm

    sudo rm ${FILES}/apache-storm-${STORM_VERSION}.tar.gz

}

function install_monasca_thresh {

    echo_summary "Install Monasca monasca_thresh"

    git_clone $MONASCA_THRESH_REPO $MONASCA_THRESH_DIR $MONASCA_THRESH_BRANCH
    (cd "${MONASCA_THRESH_DIR}"/thresh ; sudo mvn clean package -DskipTests)

    local version="$(get_version_from_pom "${MONASCA_THRESH_DIR}"/thresh)"

    sudo cp -f "${MONASCA_THRESH_DIR}"/thresh/target/monasca-thresh-${version}-shaded.jar \
      /opt/monasca/monasca-thresh.jar

    sudo useradd --system -g monasca mon-thresh || true

    sudo mkdir -p /etc/monasca || true

    sudo chown root:monasca /etc/monasca

    sudo chmod 0775 /etc/monasca

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-thresh/thresh-config.yml /etc/monasca/thresh-config.yml

    sudo chown root:monasca /etc/monasca/thresh-config.yml

    sudo chmod 0640 /etc/monasca/thresh-config.yml

    if [[ ${SERVICE_HOST} ]]; then

        # set kafka ip address
        sudo sed -i "s/metadataBrokerList: \"127\.0\.0\.1:9092\"/metadataBrokerList: \"${SERVICE_HOST}:9092\"/g" /etc/monasca/thresh-config.yml
        # set mysql ip address
        sudo sed -i "s/jdbc:mysql:\/\/127\.0\.0\.1/jdbc:mysql:\/\/${SERVICE_HOST}/g" /etc/monasca/thresh-config.yml
    fi

    sudo sed -e "
       s|%MONASCA_STATSD_PORT%|$MONASCA_STATSD_PORT|g;
    " -i /etc/monasca/thresh-config.yml

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-thresh/monasca-thresh /etc/init.d/monasca-thresh

    sudo chown root:root /etc/init.d/monasca-thresh

    sudo chmod 0744 /etc/init.d/monasca-thresh

    sudo systemctl enable monasca-thresh

}

function clean_monasca_thresh {

    echo_summary "Clean Monasca monasca_thresh"

    (cd "${MONASCA_THRESH_DIR}"/thresh ; sudo mvn clean)

    sudo systemctl disable monasca-thresh

    sudo rm /etc/init.d/monasca-thresh

    sudo rm /etc/monasca/thresh-config.yml

    sudo userdel mon-thresh || true

    sudo rm /opt/monasca/monasca-thresh.jar

}

function install_monasca_keystone_client {

    echo_summary "Install Monasca Keystone Client"

    apt_get -y install python-dev

    PIP_VIRTUAL_ENV=/opt/monasca

    (cd /opt/monasca ; sudo ./bin/pip install python-keystoneclient)

    (cd /opt/monasca ; sudo ./bin/pip install keystoneauth1)

    unset PIP_VIRTUAL_ENV

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/keystone/create_monasca_service.py /usr/local/bin/create_monasca_service.py

    sudo chmod 0700 /usr/local/bin/create_monasca_service.py


    if [[ ${SERVICE_HOST} ]]; then

        sudo /opt/monasca/bin/python /usr/local/bin/create_monasca_service.py ${SERVICE_HOST} ${OS_USERNAME} ${OS_PASSWORD} ${OS_PROJECT_NAME} ${OS_PROJECT_DOMAIN_ID} ${OS_USER_DOMAIN_ID}

    else

        sudo /opt/monasca/bin/python /usr/local/bin/create_monasca_service.py "127.0.0.1" ${OS_USERNAME} ${OS_PASSWORD} ${OS_PROJECT_NAME} ${OS_PROJECT_DOMAIN_ID} ${OS_USER_DOMAIN_ID}

    fi

}

function clean_monasca_keystone_client {

    echo_summary "Clean Monasca Keystone Client"

    sudo rm /usr/local/bin/create_monasca_service.py

    apt_get -y purge python-dev

}

function install_monasca_agent {

    echo_summary "Install Monasca monasca_agent"

    apt_get -y install python-dev
    apt_get -y install python-yaml
    apt_get -y install build-essential
    apt_get -y install libxml2-dev
    apt_get -y install libxslt1-dev

    # clients needs to be downloaded without git_clone wrapper
    # because of the GIT_DEPTH flag that affects python package version
    if [ ! -d "${MONASCA_CLIENT_DIR}" ]; then
       # project is cloned in the gate already, do not reclone
       git_timed clone $MONASCA_CLIENT_REPO $MONASCA_CLIENT_DIR
    fi
    (cd "${MONASCA_CLIENT_DIR}" ; git checkout $MONASCA_CLIENT_BRANCH ; sudo python setup.py sdist)
    MONASCA_CLIENT_SRC_DIST=$(ls -td "${MONASCA_CLIENT_DIR}"/dist/python-monascaclient*.tar.gz | head -1)

    git_clone $MONASCA_AGENT_REPO $MONASCA_AGENT_DIR $MONASCA_AGENT_BRANCH
    (cd "${MONASCA_AGENT_DIR}" ; sudo python setup.py sdist)
    MONASCA_AGENT_SRC_DIST=$(ls -td "${MONASCA_AGENT_DIR}"/dist/monasca-agent-*.tar.gz | head -1)

    sudo mkdir -p /opt/monasca-agent/

    (cd /opt/monasca-agent ; sudo virtualenv .)

    (cd /opt/monasca-agent ; sudo ./bin/pip install $MONASCA_AGENT_SRC_DIST)

    (cd /opt/monasca-agent ; sudo ./bin/pip install $MONASCA_CLIENT_SRC_DIST)

    (cd /opt/monasca-agent ; sudo ./bin/pip install kafka-python==0.9.2)

    sudo chown $STACK_USER:monasca /opt/monasca-agent

    sudo mkdir -p /etc/monasca/agent/conf.d || true

    sudo chown root:root /etc/monasca/agent/conf.d

    sudo chmod 0755 /etc/monasca/agent/conf.d

    sudo mkdir -p /usr/lib/monasca/agent/custom_checks.d || true

    sudo chown root:root /usr/lib/monasca/agent/custom_checks.d

    sudo chmod 0755 /usr/lib/monasca/agent/custom_checks.d

    sudo mkdir -p /usr/lib/monasca/agent/custom_detect.d || true

    sudo chown root:root /usr/lib/monasca/agent/custom_detect.d

    sudo chmod 0755 /usr/lib/monasca/agent/custom_detect.d

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-agent/host_alive.yaml /etc/monasca/agent/conf.d/host_alive.yaml

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/monasca-agent/monasca-reconfigure /usr/local/bin/monasca-reconfigure

    sudo chown root:root /usr/local/bin/monasca-reconfigure

    sudo chmod 0750 /usr/local/bin/monasca-reconfigure

    if [[ ${SERVICE_HOST} ]]; then

        sudo sed -i "s/--monasca_url 'http:\/\/127\.0\.0\.1:8070\/v2\.0'/--monasca_url 'http:\/\/${SERVICE_HOST}:8070\/v2\.0'/" /usr/local/bin/monasca-reconfigure
        sudo sed -i "s/--keystone_url 'http:\/\/127\.0\.0\.1:35357\/v3'/--keystone_url 'http:\/\/${SERVICE_HOST}:35357\/v3'/" /usr/local/bin/monasca-reconfigure
    fi
    sudo sed -e "
       s|%MONASCA_STATSD_PORT%|$MONASCA_STATSD_PORT|g;
    " -i /usr/local/bin/monasca-reconfigure
}

function clean_monasca_agent {

    echo_summary "Clean Monasca monasca_agent"

    sudo rm /etc/init.d/monasca-agent

    sudo rm /usr/local/bin/monasca-reconfigure

    sudo rm /etc/monasca/agent/conf.d/host_alive.yaml

    sudo chown root:root /etc/monasca/agent/conf.d/host_alive.yaml

    chmod 0644 /etc/monasca/agent/conf.d/host_alive.yaml

    sudo rm -rf /usr/lib/monasca/agent/custom_detect.d

    sudo rm -rf  /usr/lib/monasca/agent/custom_checks.d

    sudo rm -rf /etc/monasca/agent/conf.d

    sudo rm -rf /etc/monasca/agent

    sudo rm -rf /opt/monasca-agent

    apt_get -y purge libxslt1-dev
    apt_get -y purge libxml2-dev
    apt_get -y purge build-essential
    apt_get -y purge python-yaml
    apt_get -y purge python-dev

}

function install_monasca_default_alarms {
:

}

function clean_monasca_default_alarms {
:

}

function install_monasca_horizon_ui {

    echo_summary "Install Monasca Horizon UI"

    git_clone $MONASCA_UI_REPO $MONASCA_UI_DIR $MONASCA_UI_BRANCH
    (cd "${MONASCA_UI_DIR}" ; sudo python setup.py sdist)

    sudo pip install python-monascaclient

    sudo ln -sf "${MONASCA_UI_DIR}"/monitoring/enabled/_50_admin_add_monitoring_panel.py "${MONASCA_BASE}"/horizon/openstack_dashboard/local/enabled/_50_admin_add_monitoring_panel.py

    sudo ln -sf "${MONASCA_UI_DIR}"/monitoring "${MONASCA_BASE}"/horizon/monitoring

    if [[ ${SERVICE_HOST} ]]; then

        sudo sed -i "s#getattr(settings, 'GRAFANA_URL', None)#{'RegionOne': \"http:\/\/${SERVICE_HOST}:3000\", }#g" "${MONASCA_BASE}"/monasca-ui/monitoring/config/local_settings.py

    else

        sudo sed -i "s#getattr(settings, 'GRAFANA_URL', None)#{'RegionOne': 'http://localhost:3000', }#g" "${MONASCA_BASE}"/monasca-ui/monitoring/config/local_settings.py

    fi

    sudo python "${MONASCA_BASE}"/horizon/manage.py collectstatic --noinput

    sudo python "${MONASCA_BASE}"/horizon/manage.py compress --force

    restart_service apache2

}

function clean_monasca_horizon_ui {

    echo_summary "Clean Monasca Horizon UI"

    sudo rm -f "${MONASCA_BASE}"/horizon/openstack_dashboard/local/enabled/_50_admin_add_monitoring_panel.py

    sudo rm -f "${MONASCA_BASE}"/horizon/monitoring

    sudo rm -rf "${MONASCA_UI_DIR}"

}

# install node with nvm, works behind corporate proxy
# and does not result in gnutsl_handshake error
function install_node_nvm {

    echo_summary "Install Node ${NODE_JS_VERSION} with NVM ${NVM_VERSION}"

    local nvm_url=https://raw.githubusercontent.com/creationix/nvm/v${NVM_VERSION}/install.sh
    local nvm_dest=${FILES}/nvm_install.sh
    download_file ${nvm_url} ${nvm_dest}

    set -i
    bash ${nvm_dest}
    (
      source "${HOME}"/.nvm/nvm.sh >> /dev/null; \
        nvm install ${NODE_JS_VERSION}; \
        nvm use ${NODE_JS_VERSION}; \
        npm config set registry "http://registry.npmjs.org/"; \
        npm config set proxy "${HTTP_PROXY}"; \
        npm set strict-ssl false;
    )
    set +i
}

function install_monasca_grafana {

    echo_summary "Install Grafana"

    if [ ! -d "${GRAFANA_DIR}" ]; then
        git_timed clone $GRAFANA_REPO $GRAFANA_DIR --branch $GRAFANA_BRANCH --depth 1
    fi

    cd "${MONASCA_BASE}"

    mkdir grafana-build || true
    cd grafana-build
    export GOPATH=`pwd`
    mkdir -p $GOPATH/src/github.com/grafana
    cd $GOPATH/src/github.com/grafana
    cp -rf "${GRAFANA_DIR}" .

    cd grafana
    cp "${MONASCA_UI_DIR}"/grafana-dashboards/* ./public/dashboards/

    go run build.go build

    set -i

    (source "${HOME}"/.nvm/nvm.sh >> /dev/null; nvm use ${NODE_JS_VERSION}; npm config set unsafe-perm true)
    (source "${HOME}"/.nvm/nvm.sh >> /dev/null; nvm use ${NODE_JS_VERSION}; npm install)
    (source "${HOME}"/.nvm/nvm.sh >> /dev/null; nvm use ${NODE_JS_VERSION}; npm install -g grunt-cli)
    (source "${HOME}"/.nvm/nvm.sh >> /dev/null; nvm use ${NODE_JS_VERSION}; grunt --force)

    set +i

    cd "${MONASCA_BASE}"
    sudo rm -r grafana

    sudo useradd grafana || true
    sudo mkdir /etc/grafana || true
    sudo mkdir /var/lib/grafana || true
    sudo mkdir /var/lib/grafana/plugins || true
    sudo mkdir /var/log/grafana || true

    git_clone $MONASCA_GRAFANA_DATASOURCE_REPO $MONASCA_GRAFANA_DATASOURCE_DIR $MONASCA_GRAFANA_DATASOURCE_BRANCH
    sudo ln -sfF "${MONASCA_GRAFANA_DATASOURCE_DIR}" /var/lib/grafana/plugins/monasca-grafana-datasource

    sudo chown -R grafana:grafana /var/lib/grafana /var/log/grafana

    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/grafana/grafana.ini /etc/grafana/grafana.ini
    sudo cp -f "${MONASCA_API_DIR}"/devstack/files/grafana/grafana-server /etc/init.d/grafana-server
    sudo sed -i "s#/usr/sbin#"${MONASCA_BASE}"/grafana-build/src/github.com/grafana/grafana/bin#g" /etc/init.d/grafana-server
    sudo sed -i "s#/usr/share#"${MONASCA_BASE}"/grafana-build/src/github.com/grafana#g" /etc/init.d/grafana-server

    sudo systemctl enable grafana-server
}

function clean_node_nvm {
    sudo rm -rf "${HOME}"/.nvm

    sudo rm -f ${FILES}/nvm_install.sh
}

function clean_monasca_grafana {

    sudo rm -f "${MONASCA_BASE}"/grafana-build

    sudo systemctl disable grafana-server

    sudo rm /etc/init.d/grafana-server

    sudo rm -r /etc/grafana

    sudo rm -r /var/lib/grafana

    sudo rm -r /var/log/grafana

}

function install_go {
    echo_summary "Install Go ${GO_VERSION}"

    local go_tarball=go${GO_VERSION}.linux-amd64.tar.gz
    local go_tarball_url=https://storage.googleapis.com/golang/${go_tarball}
    local go_tarball_dest=${FILES}/${go_tarball}

    download_file ${go_tarball_url} ${go_tarball_dest}

    sudo tar -C /usr/local -xzf ${go_tarball_dest}
    export PATH=$PATH:/usr/local/go/bin
}

function clean_go {
    echo_summary "Clean Go ${GO_VERSION}"

    sudo rm -f ${FILES}/go${GO_VERSION}*
    sudo rm -rf /usr/local/go*
    export PATH=$(echo $PATH | sed -e 's|:/usr/local/go/bin||')
}

###### extra functions
function recreate_users {
  local db=$1
  local users=$2
  local hosts=$3
  recreate_users_$DATABASE_TYPE $db $users $hosts
}

function recreate_users_mysql {
  local db=$1
  local -n users=$2
  local -n hosts=$3
  for user in "${users[@]}"; do
    for host in "${hosts[@]}"; do
      # loading grants needs to be done from localhost and by root at this very point
      # after loading schema is moved to post-config it could be possible to this as
      # DATABASE_USER
      mysql -uroot -p$DATABASE_PASSWORD -h127.0.0.1 -e "GRANT ALL PRIVILEGES ON $db.* TO '$user'@'$host' identified by 'password';"
    done
  done
}

# Validate a program version string is of the form 1.0.0.
# Return 0 if a valid program version string, otherwise 1.
function validate_version {
    version_regex="^([0-9]+\.)?([0-9]+\.)?([0-9]+)$"

    if [[ $1 =~ $version_regex ]];
    then
        return 0
    else
        return 1
    fi
}

# Compares two program version strings of the form 1.0.0.
# Returns "lt" if $1 is less than $2, "eq" if equal, and "gt" if greater than.
function compare_versions {
    if [[ $1 == $2 ]]
    then
        echo eq
        return
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            echo gt
            return
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            echo lt
            return
        fi
    done
    echo eq
    return
}

# Prints the version specified in the pom.xml file in the directory given by
# the argument
function get_version_from_pom {
  python -c "import xml.etree.ElementTree as ET; \
    print(ET.parse(open('$1/pom.xml')).getroot().find( \
    '{http://maven.apache.org/POM/4.0.0}version').text)"
}

# Allows this script to be called directly outside of
# the devstack infrastructure code. Uncomment to use.
#if [[ $(type -t is_service_enabled) != 'function' ]]; then
#
#    function is_service_enabled {
#
#        return 0
#
#     }
#fi
#if [[ $(type -t echo_summary) != 'function' ]]; then
#
#    function echo_summary {
#
#        echo "$*"
#
#    }
#
#fi

# check for service enabled
if is_service_enabled monasca; then

    if [[ "$1" == "stack" && "$2" == "pre-install" ]]; then
        # Set up system services
        echo_summary "Configuring Monasca system services"
        pre_install_monasca

    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        # Perform installation of service source
        echo_summary "Installing Monasca"
        install_monasca

    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        # Configure after the other layer 1 and 2 services have been configured
        echo_summary "Configuring Monasca"
        post_config_monasca

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        # Initialize and start the Monasca service
        echo_summary "Initializing Monasca"
        extra_monasca
    fi

    if [[ "$1" == "unstack" ]]; then
        # Shut down Monasca services
        echo_summary "Unstacking Monasca"
        unstack_monasca
    fi

    if [[ "$1" == "clean" ]]; then
        # Remove state and transient data
        # Remember clean.sh first calls unstack.sh
        echo_summary "Cleaning Monasca"
        clean_monasca
    fi
fi

# download_file
#  $1 - url to download
#  $2 - location where to save url to
#
# Download file only when it not exists or there is newer version of it.
#
#  Uses global variables:
#  - OFFLINE
#  - DOWNLOAD_FILE_TIMEOUT
# note(trebskit) maybe this function will enter upstream devstack in case it does
#                we should remove it from here
function download_file {
    local url=$1
    local file=$2

    # If in OFFLINE mode check if file already exists
    if [[ ${OFFLINE} == "True" ]] && [[ ! -f ${file} ]]; then
        die $LINENO "You are running in OFFLINE mode but
                     the target file \"$file\" was not found"
    fi

    local curl_z_flag=""
    if [[ -f ${file} ]]; then
        # If the file exists tell cURL to download only if newer version
        # is available
        curl_z_flag="-z $file"
    fi

    # yeah...downloading...devstack...hungry..om, om, om
    local timeout=0

    if [[ -n "${DOWNLOAD_FILE_TIMEOUT}" ]]; then
        timeout=${DOWNLOAD_FILE_TIMEOUT}
    fi

    time_start "download_file"
    _safe_permission_operation ${CURL_GET} -L $url --connect-timeout $timeout --retry 3 --retry-delay 5 -o $file $curl_z_flag
    time_stop "download_file"

}

#Restore errexit
$ERREXIT

# Restore xtrace
$XTRACE
