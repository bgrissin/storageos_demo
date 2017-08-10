export HOSTNAME=$HOSTNAME
export KV_ADDR=127.0.0.1:8500
export KV_BACKEND=consul
export API_PORT=5705
export NATS_PORT=4222
export NATS_CLUSTER_PORT=8222
export SERF_PORT=13700
export DFS_PORT=17100
export LOG_LEVEL=info.LOG_FORMAT

export STORAGEOS_USERNAME=storageos STORAGEOS_PASSWORD=storageos

sudo mkdir /var/lib/storageos
sudo modprobe nbd nbds_max=1024
wget -O /etc/docker/plugins/storageos.json http://docs.storageos.com/assets/storageos.json
docker run -d --name storageos -e HOSTNAME --net=host --pid=host --privileged --cap-add SYS_ADMIN --device /dev/fuse -v /var/lib/storageos:/var/lib/storageos:rshared -v /run/docker/plugins:/run/docker/plugins storageos/node:latest server

export ADVERTISE_IP=$ip

echo "y" | docker plugin install --alias storageos storageos/plugin ADVERTISE_IP=${ADVERTISE_IP}

curl -sSL https://github.com/storageos/go-cli/releases/download/0.0.10/storageos_linux_amd64 > /usr/local/bin/storageos
chmod +x /usr/local/bin/storageos
