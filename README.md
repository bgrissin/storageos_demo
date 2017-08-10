Here is the complete doc set from StorageOS - https://docs.storageos.com/docs/introduction/overview

First create 2 AWS t2.medium instances (I used the amazon AMIs) on AWS,  then create a security group along with an ssh key.  also add an EBS volume to each host (8GB will be fine for a demo)

                                        details details details

ssh into both of your instances and install docker.  Later we'll create a swarm cluster using the 2 AWS instances you just created.

    $ sudo su -
    $ yum update -y
    $ yum install docker -y
    $ service docker start 
    $ service docker enable 
    $ usermod -aG docker ec2-user

Next, setup the shareable folder capability for each AWS instance - (run as root or sudo each command)

    $ mount --make-shared /
    $ sed -i.bak -e  's:^\(\ \+\)"$unshare" -m -- nohup:\1"$unshare" -m --propagation shared -- nohup:'  /etc/init.d/docker
    $ service docker restart

Now create your swarm cluster

    $ docker swarm init

take the output from your docker swarm init output provided to the other node and join that node to this master

    $ docker swarm join --token SWMTKN-1-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  <ip_addr of swarm master>:2377

Next lets get a kv store setup on each node - StorageOS currently uses Consul, (etcd and others are scheduled soon).   You can do this     with compose, but since we are only dealing with 2 nodes here. In the example below a docker container for consul is run on each node.

On node one (the swarm master) set these env vars accordingly - (for AWS nodes the ip env var is the private IP, not the public IP)

    $ export ip=10.0.0.1
    $ export num_nodes=2
    $ export leader_ip=10.0.0.1

And on node 2 - note the only difference is ip

    $ export ip=10.0.0.2
    $ export num_nodes=2
    $ export leader_ip=10.0.0.1

Then run the consul container along with these arguments on each AWS instance starting with the first instance (swarm manager node)

    $ docker run -d --name consul --net=host consul agent -server -bind=${ip} -client=0.0.0.0 -bootstrap-expect=${num_nodes} -retry-join=${leader_ip}
    $ docker node ls
      ID                           HOSTNAME       STATUS  AVAILABILITY  MANAGER STATUS
      ml1evr5m09gku3x7ettrctt98 *  ip-10-0-0-1     Ready   Active         Leader
      qerjcc498kx0i33oqg62mu1lk    ip-10-0-0-2     Ready   Active  

Now your ready to setup StorageOS on each swarm cluster member.  You can manually go through the steps below or you can use the setup.sh from this repo
 
- To use the setup.sh, copy the setup.sh to each of the nodes and run.  You may have to chmod +X setup.sh to get it to run 
 
Each node has to have the storageos node container running.  It is recommended you start by installing the StorageOS node container on the       kv leader first, then adding it to each cluster node.  Here are the details from StorageOS - https://hub.docker.com/r/storageos/node/

            * HOSTNAME: Hostname of the Docker node, only if you wish to override it.
            * ADVERTISE_IP: IP address of the Docker node, for incoming connections. Defaults to first non-loopback address.
            * STORAGEOS_USERNAME: Username to authenticate to the API with. Defaults to storageos.
            * STORAGEOSPASSWORD: Password to authenticate to the API with. Defaults to storageos.
            * KV_ADDR: IP address/port of the Key/Vaue store. Defaults to 127.0.0.1:8500
            * KV_BACKEND: Type of KV store to use. Defaults to consul. boltdb can be used for single node testing.
            * API_PORT: Port for the API to listen on. Defaults to 5705 (IANA Registered).
            * NATS_PORT: Port for NATS messaging to listen on. Defaults to 4222.
            * NATS_CLUSTER_PORT: Port for the NATS cluster service to listen on. Defaults to 8222.
            * SERF_PORT: Port for the Serf protocol to listen on. Defaults to 13700.
            * DFS_PORT: Port for DirectFS to listen on. Defaults to 17100.
            * LOG_LEVEL: One of debug, info, warning or error. Defaults to info.LOG_FORMAT
            * ADVERTISE_IP: On AWS, this is typically the private IP of the host. 
++

    $ export HOSTNAME=$HOSTNAME
    $ export STORAGEOS_USERNAME=storageos
    $ export STORAGE_PASSWORD=storageos
    $ export KV_ADDR=127.0.0.1:8500
    $ export KV_BACKEND=consul
    $ export API_PORT=5705
    $ export NATS_PORT=4222
    $ export NATS_CLUSTER_PORT=8222
    $ export SERF_PORT=13700
    $ export DFS_PORT=17100
    $ export LOG_LEVEL=info.LOG_FORMAT
    $ export ADVERTISE_IP=$ip

Once your env vars are set, you can then begin to execute the storageOS installations

    $ sudo mkdir /var/lib/storageos
    $ sudo modprobe nbd nbds_max=1024
    $ wget -O /etc/docker/plugins/storageos.json http://docs.storageos.com/assets/storageos.json
    $ docker run -d --name storageos -e HOSTNAME --net=host --pid=host --privileged --cap-add SYS_ADMIN --device /dev/fuse -v /var/lib/storageos:/var/lib/storageos:rshared -v /run/docker/plugins:/run/docker/plugins store/storageos/node:latest server


Next setup the StorageOS Docker plugin capability. Doing so will allow you create container volumes using the docker CLI versus using the              StorageOS CLI

    $ docker plugin install --alias storageos storageos/plugin ADVERTISE_IP=${ADVERTISE_IP}

Last setup the StorageOS cli tool using a local install. 

    $ curl -sSL https://github.com/storageos/go-cli/releases/download/0.0.10/storageos_linux_amd64 > /usr/local/bin/storageos
    $ chmod +x /usr/local/bin/storageos

You should be able to run the storageOS cli, test by running. *make certain your $PATH includes /usr/local/bin

    $ storageos -v

So what you can do at this point is to create volumes using the StorageOS CLI or via the Docker CLI.  This is what the plugin (v2)         feature provides

    $ docker volume create --driver=storageos test_volume
    test_volume

    $ docker container run -it --volume test_volume:/data busybox sh
    Unable to find image 'busybox:latest' locally
    latest: Pulling from library/busybox
    9e87eff13613: Pull complete 
    Digest: sha256:2605a2c4875ce5eb27a9f7403263190cd1af31e48a2044d400320548356251c4
    Status: Downloaded newer image for busybox:latest

Here is a link to some examples using the storageos cli docs - http://docs.storageos.com/docs/manage/volumes/

