#!/bin/bash

#=================================================
# SET ALL CONSTANTS
#=================================================

app=$YNH_APP_INSTANCE_NAME
app_runner="runner"
version="2.1.0"
runner_version="latest"
dbname=$app
dbuser=$app
final_path="/opt/$app"

# Detect the system architecture to download the right tarball
# NOTE: `uname -m` is more accurate and universal than `arch`
# See https://en.wikipedia.org/wiki/Uname
if [ -n "$(uname -m | grep 64)" ]; then
        ARCHITECTURE="amd64"
        DOCKER_ARCH="amd64"
elif [ -n "$(uname -m | grep 86)" ]; then
        ARCHITECTURE="386"
        DOCKER_ARCH="amd64"
elif [ -n "$(uname -m | grep arm)" ]; then
        ARCHITECTURE="arm"
        DOCKER_ARCH="armhf"
else
        echo 'Unable to detect your achitecture, please open a bug describing \
        your hardware and the result of the command "uname -m".'
        exit 1
fi

# Check architecture & set Drone image
if [ $ARCHITECTURE = "amd64" ]; then
    DRONE_IMAGE=drone/drone:$version
    DRONE_RUNNER_IMAGE=drone/drone-runner-docker:$runner_version
elif [ $ARCHITECTURE = "arm" ]; then
    DRONE_IMAGE=armhfbuild/drone:$version
    DRONE_RUNNER_IMAGE=armhfbuild/drone-runner-docker:$runner_version
else
    ynh_die "Unsupported architecture, aborting."
fi

#=================================================
# DEFINE ALL COMMON FONCTIONS
#=================================================

create_dir() {
    mkdir -p "$final_path/data"
    mkdir -p "/var/log/$app"
}

create_drone_env() {
    # Install the Drone configuration file
    cat << EOF |  tee -a "$final_path"/dronerc
DRONE_GIT_ALWAYS_AUTH=false
DRONE_RUNNER_CAPACITY=2
DRONE_SERVER_HOST=$domain
DRONE_SERVER_PROTO=https
DRONE_TLS_AUTOCERT=false
DRONE_DATABASE_DRIVER=mysql
DRONE_DATABASE_DATASOURCE=$dbuser:$dbpass@unix(/host_mysql.sock)/$dbname?parseTime=true
DRONE_USER_CREATE=username:$admin,admin:true
DRONE_GITEA_SERVER=$remote_gitea
DRONE_GITEA_CLIENT_ID=$client_id
DRONE_GITEA_CLIENT_SECRET=$client_secret
DRONE_RPC_SECRET=$rpc_secret
DRONE_RUNNER_CAPACITY=2
DRONE_RUNNER_NAME=$domain
DRONE_RPC_PROTO=https
EOF

}

create_container() {
    systemctl restart docker

    # Install Drone
    docker pull $DRONE_IMAGE
    docker run \
        --volume=/var/run/mysqld/mysqld.sock:/host_mysql.sock \
        --volume=/var/run/docker.sock:/var/run/docker.sock \
        --volume=/var/lib/drone:/opt/drone/data \
        --env-file "$final_path/dronerc" \
        --restart=always \
        --publish=$port:80 \
        --detach=true \
        --name=$app \
        $DRONE_IMAGE

    docker pull $DRONE_RUNNER_IMAGE
    docker run -d \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --env-file "$final_path/dronerc" \
        -p 3000:3000 \
        --restart always \
        --detach=true \
        --name $app_runner \
        $DRONE_RUNNER_IMAGE
}

config_nginx() {
    ynh_replace_string "YNH_DRONE_PORT" "$port" ../conf/nginx.conf
    ynh_add_nginx_config
}

set_access_settings() {
    ynh_app_setting_set $app skipped_uris "/api/"
    if [ "$is_public" = '1' ]
    then
        ynh_app_setting_set $app unprotected_uris "/"
    fi
}
