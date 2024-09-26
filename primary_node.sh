#!/bin/sh

Red='\033[1;91m'
Color_off='\033[0m'
Green='\033[1;32m'
Blue='\033[1;34m'
failure=false

Command_status(){
    echo -e "${Blue}Running : ${Color_off} $*"
    "$@"
    if [ $? -eq 0 ];
    then
        echo -e "${Green}success ${Color_off}"
    else
        echo -e "$1 ${Red}failed ${Color_off}"
        failure=true
    fi
}

# set -e          # to stop running code when error occurs

# updating all packages inside the machine
Command_status sudo yum update -y

# creating a repo in yum package installer
echo -e "\n${Blue}Creating a repo in yum for installing mongodb.${Color_off}"
cat <<EOF | sudo tee /etc/yum.repos.d/mongodb-org-7.0.repo
[mongodb-org-7.0]
name =MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
EOF

# installing mongodb (includes mongoshell, mongo deamon)
echo -e "\n${Blue}Installing mongodb.${Color_off}"
sudo yum update -y
Command_status sudo yum install mongodb-org -y
if [$failure -eq true]; 
then
    echo -e "${Blue}Retrying in a while.${Color_off}"
    sleep 90
    Command_status sudo yum install mongodb-org -y
fi

# starting up mongo deamon 
echo -e "\n${Blue}Starting mongodb.${Color_off}"
sudo systemctl start mongod
sudo systemctl enable mongod

# enhancing the mongo configuration file
echo -e "\n${Blue}Changing configuration file of mongo.${Color_off}"
sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0\n/' /etc/mongod.conf
sudo sed -i '/#replication:/c\replication:\n  replSetName: "m1"' /etc/mongod.conf
sudo systemctl restart mongod

# sudo sleep 60
# Command_status bash -c 'echo "rs.secondaryOk()" | mongosh'
if ["$failure" -eq true]; then
    echo -e "\n${Red}There is an issue with the Configuration File.${Color_off}"
    exit 1
fi

# initialising mongosetup in primary_ip
ehco 'rs.initiate()' | mongosh
echo 'rs.add("{$(other_ip):27017}")' | mongosh # change other ip with instance ip
echo 'rs.add("{$(other_ip2):27017}")' | mongosh
echo 'db.createUser({ user: "manju", pwd: "hellotest123", roles: [{ role: "root", db: "admin"},{ role: "readWrite", db: "admin"}]})' | mongosh

# opening port for mongodb
echo -e "\n${Green}Allowing flow through port 27017"
sudo firewall-cmd --zone=public --add-port=27017/tcp --permanent
Command_status sudo firewall-cmd --reload

# installing docker 
Command_status sudo yum install docker -y