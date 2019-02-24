#!/bin/bash

#=================================================
# SET ALL CONSTANTS
#=================================================

app=$YNH_APP_INSTANCE_NAME
version="1.0.0-rc.5"
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
elif [ $ARCHITECTURE = "arm" ]; then
    DRONE_IMAGE=armhfbuild/drone:$version
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
DRONE_SERVER_PROTO=http
DRONE_TLS_AUTOCERT=false
DRONE_DATABASE_DRIVER=mysql
DRONE_DATABASE_DATASOURCE=$dbuser:$dbpass@unix(/host_mysql.sock)/$dbname?parseTime=true
DRONE_USER_CREATE=username:$admin,admin:true
EOF

    [ -z "$remote_gogs" ] || echo "DRONE_GOGS_SERVER=$remote_gogs" | tee -a "$final_path/dronerc"

    [ -z "$remote_gitea" ] || echo "DRONE_GITEA_SERVER=$remote_gitea" | tee -a "$final_path/dronerc"

    if [[ ! -z "$remote_github" ]]; then
        cat << EOF | tee -a "$final_path"/dronerc
DRONE_GITHUB_SERVER=$remote_github
DRONE_GITHUB_CLIENT_ID=$client_id
DRONE_GITHUB_CLIENT_SECRET=$client_secret
EOF
    fi

    if [[ ! -z "$remote_gitlab" ]]; then
        cat << EOF | tee -a "$final_path"/dronerc
DRONE_GITLAB_SERVER=$remote_gitlab
DRONE_GITLAB_CLIENT_ID=$client_id
DRONE_GITLAB_CLIENT_SECRET=$client_secret
EOF
    fi

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
