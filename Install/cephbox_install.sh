#!/bin/bash

# This script is to deploy
# - Ceph cluster (single node and multi-node)
# - s3 compatible RGW
# - Ente Photo server
#
# usage "bash cephbox-install.sh"

# Tested version details:
#   - debian 12.7

### For colouring
GREEN='\033[0;32m'
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
BLUE="\033[0;34m"
NOCOLOR="\033[0m"
BOLD="\033[1;33m"

### initial check for privileged user
if [ "$(id -u)" != "0" ]
then
  echo -e "${GREEN}This script must be run as root ${NOCOLOR}\n" 1>&2 exit 1
fi


### Declare variables
cephadm_location="https://download.ceph.com/rpm-squid/el9/noarch/cephadm"
ceph_version="19.2.0"
container_image="quay.io/ceph/ceph:v19.2.0"
grafana_image="quay.io/ceph/ceph-grafana:9.4.12"
get_pvt_ipaddress=`hostname -I | awk '{print $1}'`
#get_public_ipaddress=`curl -s https://icanhazip.com`
realm_name=test_realm
zonegroup_name=default
zone_name=test_zone
rgw_placement=`hostname -s`
rgw_user=s3user
dashboard_user=admin
dashboard_password=admin

### Define precheck and pre-requisities functions
###

# 1. Adding condition to check whether the cluster is already installed or not
function cephalreadythere() {
    ceph_fsid=$(cephadm shell -- ceph fsid 2> /dev/null)
    if [ "$?" -eq 0 ]; then
        echo -e "\n${RED}This node already has a ceph cluster with cluster ID:${NOCOLOR} $ceph_fsid.\nSo Dropping the default installation"
        echo -e "\n${BLUE}Please review the cluster ${RED} $ceph_fsid ${NOCOLOR} and proceed further. For more options: execute the command ${YELLOW}bash install.sh --help${NOCOLOR}\n" 1>&2 exit 1
        exit 1
    fi
}

# 2. Adding condition whether any free disks are available or not
function freeavailabledisk() {
  free_disks=()
  for disk in $(lsblk -dn -o NAME,TYPE | awk '$2 == "disk" {print $1}'); do
     partitions=$(lsblk -n -o NAME /dev/$disk | wc -l)
     if [ "$partitions" -eq 1 ]; then
       has_fs=$(lsblk -f /dev/$disk | awk 'NR>1 {print $2}' | grep -v '^$')
       if [ -z "$has_fs" ]; then
         free_disks+=("/dev/$disk")
         echo -e "\n${BLUE}Free disk found: /dev/$disk ${NOCOLOR}\n"
       fi
     fi
  done
  if [ ${#free_disks[@]} -eq 0 ]; then
    echo -e "\n${RED}No free disks without partitions or filesystems found.\n Attach new disk or clean/wipe the existing disk prior to proceed further... Once its done, re-run the script again...${NOCOLOR}\n${YELLOW}bash install.sh --help${NOCOLOR} - will show more options for this script..." 1>&2 exit 1
    exit 1
  fi
}

# 3. debian prerequsites
function debian_prerequsites() {
  echo -e "${GREEN}Installing podman, lvm2, chrony...${NOCOLOR}\n"
  sudo apt update
  sudo apt install -y lvm2 podman chrony sudo curl
}

# 4. debian package update
function debian_update() {
  echo -e "${GREEN}Updating package lists...${NOCOLOR}\n"
  sudo apt update
  echo -e "${GREEN}Upgrading packages...${NOCOLOR}\n"
  sudo apt upgrade -y
  echo -e "${GREEN}Running full distribution upgrade...${NOCOLOR}\n"
  sudo apt full-upgrade -y
  echo -e "${GREEN}Cleaning up unnecessary packages...${NOCOLOR}\n"
  sudo apt autoremove -y
  sudo apt autoclean
  echo -e "${GREEN}System update completed...${NOCOLOR}\n"
}

### Cephadm installation
###

# debian cephadm binary setting
function debian_cephadm() {
  echo -e "${GREEN}configuring cephadm...${NOCOLOR}\n"
  cd /sbin/ && curl -# --remote-name --location "${cephadm_location}"
  chmod +x /sbin/cephadm
  /sbin/cephadm add-repo --version "${ceph_version}"
  echo "export PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/sbin:/usr/local/bin" >> ~/.bashrc
  source ~/.bashrc
}

# install ceph cluster using cephadm

function multi_node_deployment() {
  echo -e "${CYAN}\n\nInstalling Ceph Cluster...🛠️  ${NOCOLOR}\n"
  echo -e "${GREEN}Pulling  ${container_image} ${NOCOLOR}"
  podman pull "${container_image}"
  date_var1=`date "+%Y-%m-%d-%T"`
  cephadm --image "${container_image}" bootstrap --mon-ip "${get_pvt_ipaddress}" --initial-dashboard-user "${dashboard_user}" --initial-dashboard-password "${dashboard_password}" | tee /root/ceph_install.out-${date_var1}
  cephadm shell -- ceph status
  echo -e "${CYAN}Found free disk 💾
Starting OSD deployment. Please wait... ⏳${NOCOLOR}\n"
  sleep 30
  cephadm shell -- ceph orch apply osd --all-available-devices
  sleep 30
  cephadm shell -- ceph config set mgr mgr/cephadm/container_image_grafana "${grafana_image}"
  sleep 5
  cephadm shell -- ceph mgr fail
  echo -e "${GREEN}Verifying OSD is up and running...${NOCOLOR}\n"
  cephadm shell -- ceph orch ps --daemon_type osd
  echo -e "${CYAN}\n\nCeph cluster successfully deployed 🐙🐙🐙 🚀🚀🚀 ${NOCOLOR}\n"
  cephadm shell -- ceph mgr fail
  cephadm shell -- ceph -s
  cephadm shell -- ceph orch ls
  date_var2=`date "+%Y-%m-%d-%T"`
  echo "Ceph Manager dashboard details: " > /root/ceph_mgr_install.out-${date_var2}
  cephadm shell -- ceph mgr services >> /root/ceph_mgr_install.out-${date_var2}
  echo -e "${CYAN}\n\n-------------------------------------"
  echo -e "Ceph Dashboard details: \n"
  echo -e "       URL: https://$(hostname):8443 "
  echo -e "      User: $dashboard_user"
  echo -e "  Password: $dashboard_password"
  echo -e "-------------------------------------${NOCOLOR}"
  echo "Ceph Initial Status: " >> /root/ceph_mgr_install.out-${date_var2}
  cephadm shell -- ceph -s >> /root/ceph_mgr_install.out-${date_var2}
  cephadm shell -- ceph orch host ls >> /root/ceph_mgr_install.out-${date_var2}
   echo "-------------------------------------" >> /root/ceph_mgr_install.out-${date_var2}

}

function single_node_deployment() {
  echo -e "${CYAN}\n\nInstalling Ceph Cluster...🛠️  ${NOCOLOR}\n"
  echo -e "${GREEN}Pulling  ${container_image} ${NOCOLOR}"
  podman pull "${container_image}"
  date_var1=`date "+%Y-%m-%d-%T"`
  cephadm --image "${container_image}" bootstrap --mon-ip "${get_pvt_ipaddress}" --initial-dashboard-user "${dashboard_user}" --initial-dashboard-password "${dashboard_password}" --single-host-defaults | tee /root/ceph_install.out-${date_var1}
  cephadm shell -- ceph status
  echo -e "${CYAN}Found free disk 💾
Starting OSD deployment. Please wait... ⏳${NOCOLOR}\n"
  sleep 30
  cephadm shell -- ceph orch apply osd --all-available-devices
  sleep 30
  cephadm shell -- ceph config set mgr mgr/cephadm/container_image_grafana "${grafana_image}"
  sleep 5
  cephadm shell -- ceph mgr fail
  echo -e "${GREEN}Verifying OSD is up and running...${NOCOLOR}\n"
  cephadm shell -- ceph orch ps --daemon_type osd
  echo -e "${GREEN}Overriding default configurations to allow single node ceph cluster setup...${NOCOLOR}\n"
  cephadm shell -- ceph config set global mon_allow_pool_delete true
  cephadm shell -- ceph config set global osd_pool_default_min_size 1
  cephadm shell -- ceph config set global osd_pool_default_size 1
  echo -e "${CYAN}\n\nCeph cluster successfully deployed 🐙🐙🐙 🚀🚀🚀 ${NOCOLOR}\n"
  cephadm shell -- ceph mgr fail
  cephadm shell -- ceph -s
  cephadm shell -- ceph orch ls
  date_var2=`date "+%Y-%m-%d-%T"`
  echo "Ceph Manager dashboard details: " > /root/ceph_mgr_install.out-${date_var2}
  cephadm shell -- ceph mgr services >> /root/ceph_mgr_install.out-${date_var2}
  echo -e "${CYAN}\n\n-------------------------------------"
  echo -e "Ceph Dashboard details: \n"
  echo -e "       URL: https://$(hostname):8443 "
  echo -e "      User: $dashboard_user"
  echo -e "  Password: $dashboard_password"
  echo -e "-------------------------------------${NOCOLOR}"
#  echo "Ceph Initial Status: " >> /root/ceph_mgr_install.out-${date_var2}
#  cephadm shell -- ceph -s >> /root/ceph_mgr_install.out-${date_var2}
#  cephadm shell -- ceph orch host ls >> /root/ceph_mgr_install.out-${date_var2}
#   echo "-------------------------------------" >> /root/ceph_mgr_install.out-${date_var2}
}

# Pre-requesites for rgw - realm/zonegroup/zone..etc
function rgwPrerequsites() {
  echo -e "${GREEN}Configuring realm...${NOCOLOR}\n"
  cephadm shell -- radosgw-admin realm create --rgw-realm="${realm_name}" --default
  echo -e "${GREEN}Configuring zonegroup...${NOCOLOR}\n"
  cephadm shell -- radosgw-admin zonegroup create --rgw-zonegroup="${zonegroup_name}" --master --default
  echo -e "${GREEN}Configuring zone...${NOCOLOR}\n"
  cephadm shell -- radosgw-admin zone create --rgw-zonegroup="${zonegroup_name}" --rgw-zone="${zone_name}" --master --default
  echo -e "${GREEN}Performing period update...${NOCOLOR}\n"
  cephadm shell -- radosgw-admin period update --rgw-realm="${realm_name}" --commit
}

# rgw deployment
function rgwDeployment() {
  echo -e "${GREEN}Deploying rgw...${NOCOLOR}\n"
  cephadm shell -- ceph orch apply rgw myhomergw --realm="${realm_name}" --zone="${zone_name}" --placement="1 $(rgw_placement)"
}

# rgw user
function rgwUser() {
  echo -e "${GREEN}Creating rgw user...${NOCOLOR}\n"
  cephadm shell -- radosgw-admin user create --uid="${rgw_user}" --display-name="S3 user" --email="s3user@example.com"
  cephadm shell -- ceph health mute POOL_NO_REDUNDANCY
  cephadm shell -- ceph mgr fail
}

# Fetching rgw user
function gets3User() {
  date_var3=`date "+%Y-%m-%d-%T"`
  echo -e "${GREEN}Details to configure s3cmd/aws cli/any other s3 client...${NOCOLOR}\n" | tee /root/ceph_install.out-${date_var3}
  apt update
  apt install -y s3cmd jq
  ACCESS_KEY=`cephadm shell -- radosgw-admin user info --uid="${rgw_user}" | jq  -r '.keys[0].access_key'`
  SECRET_KEY=`cephadm shell -- radosgw-admin user info --uid="${rgw_user}" | jq  -r '.keys[0].secret_key'`
  ENDPOINT="${get_pvt_ipaddress}":80
  echo -e "${GREEN}Access Key:${NOCOLOR} $ACCESS_KEY" >> /root/ceph_install.out-${date_var3}
  echo -e "${GREEN}Secret Key:${NOCOLOR} $SECRET_KEY" >> /root/ceph_install.out-${date_var3}
  echo -e "${GREEN}Endpoint Details(from the node):${NOCOLOR} $ENDPOINT" >> /root/ceph_install.out-${date_var3}
  echo -e "${GREEN}Feel free to configure your fevorate s3 client..${NOCOLOR}\n"
  cephadm shell -- ceph mgr fail
#  s3cmd mb s3:///homebucket
}

function enteapp_install() {
# Create directory

read -p 'Enter RGW bucket name:' BUCKET_NAME
read -p 'Enter Access Key:' ACCESS_KEY
read -p 'Enter Secret Key:'  SECRET_KEY
read -p 'Enter RGW Endpoint with  port (IP:Port) :' ENDPOINT

echo -e "\n${YELLOW} Creating directory 'ente' ${NOCOLOR}"
mkdir ente && cd ente

# Copy the starter compose.yaml and its support files from the repository onto your directory

echo -e "\n${YELLOW} Downloading compose.yaml ${NOCOLOR}"

curl -LO https://raw.githubusercontent.com/karunjosy/CephBox/refs/heads/main/ente_with_ceph/compose.yaml

mkdir -p scripts/compose
cd scripts/compose

echo -e "\n${YELLOW} Modifying credentials.yaml ${NOCOLOR}"

curl -LO https://raw.githubusercontent.com/karunjosy/CephBox/refs/heads/main/ente_with_ceph/credentials.yaml
file_path=~/ente/scripts/compose/credentials.yaml

sed -i "s/ACCESS_KEY/${ACCESS_KEY/}/g" "$file_path"
sed -i "s/SECRET_KEY/${SECRET_KEY}/g" "$file_path"
sed -i "s/BUCKET_NAME/${BUCKET_NAME}/g" "$file_path"
sed -i "s/ENDPOINT/${ENDPOINT}/g" "$file_path"
cd ../..

# Install docker and docker-compose if not present

echo -e "\n${YELLOW} Installing docker and docker-compose ${NOCOLOR}"
apt install docker.io -y
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version

# docker engine install
apt install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update -y
apt install -y  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker version

#cd ~/ente
#nohup docker-compose up &

echo -e "\n${CYAN}Prerequisites completed.
\nGoto 'ente' directory and run 'docker-compose up -d' to initialize Ente Museum server${NOCOLOR} 🚀🚀🚀 "
}

# Purge the ceph cluster from this node
function cephpurgenode() {
  echo -e "\n${GREEN}You have selected the option for puring the ceph in this node..${NOCOLOR}"
  ceph_fsid=$(cephadm shell -- ceph fsid 2> /dev/null)
  if [[ -z "$ceph_fsid" ]]; then
    echo -e "\n${GREEN}But here, the script cannot find a valid fsid for ceph.. So manual checking and removal is needed to purge at this stage..\n ${NOCOLOR}" 1>&2
    exit 1
  fi
  cephadm shell -- ceph -s
  echo -e "\n${RED}Do you want to purge the cluster with ID: ${BLUE} $ceph_fsid ${NOCOLOR}"
  echo -e "\n${GREEN}Keep in mind, purging can lead to data loss in case of any data which is there on the cluster...\nConfirm whether you want to proceed with purge: (${BLINKING}${RED}yes/no${NOCOLOR}): "
  read condition1
    case $condition1 in
         [yY][Ee][Ss])
           cephadm shell -- ceph mgr module disable cephadm
           cephadm rm-cluster --force --zap-osds --fsid $ceph_fsid
           echo -e "\n${GREEN}Purging completed...Check manually..${NOCOLOR}"
         ;;

         *) echo "Invalid input..."
            ;;
    esac

}

# To set the static ip
function staticipset() {
   # Print info and fetch the details from the user
   echo -e "${GREEN} This script can be used to set the static ip address for debian..\n\n ${NOCOLOR}\n${CYAN}These are the available devices in this machine:${NOCOLOR}\n "
   echo -ne "\n${CYAN}-----------<Current IP and Interface details>----------------${NOCOLOR}\n"
   ip a || ifconfig
   echo -ne "\n${CYAN}-----------<Current routes>----------------${NOCOLOR}\n"
   ip r show
   echo -ne "\n${CYAN}------------------------------------${NOCOLOR}\n"
   # Variables
   echo -ne "${GREEN}Review the above result before choosing the device name and choose the network interface which you want to set the static IP(eg: "enp1s0"):${NOCOLOR} "
   read INTERFACE
   echo -ne "${GREEN}Enter the IP address:${NOCOLOR} "
   read IP_ADDRESS
   echo -ne "${GREEN}Enter the netmask:${NOCOLOR} "
   read NETMASK
   echo -ne "${GREEN}Enter the gateway:${NOCOLOR} "
   read GATEWAY
   echo -ne "${GREEN}Enter the DNS1:${NOCOLOR} "
   read DNS1
   # Adding google DNS to resolve from internet - in case if local DNS is not working
   DNS2="8.8.4.4"
  # Confirmation
   echo -ne "\n${CYAN}-----------<Details>----------------${NOCOLOR}\n"
   echo -ne "\n${GREEN}Interface detail: ${BLINKING}${RED}$INTERFACE ${NOCOLOR}"
   echo -ne "\n${GREEN}IPAddress: ${BLINKING}${RED}$IP_ADDRESS ${NOCOLOR}"
   echo -ne "\n${GREEN}Netmask: ${BLINKING}${RED}$NETMASK ${NOCOLOR}"
   echo -ne "\n${GREEN}Gateway: ${BLINKING}${RED}$GATEWAY ${NOCOLOR}"
   echo -ne "\n${GREEN}DNS infomation:\n  ${BLINKING}${RED}- DNS1: $DNS1 \n  - DNS2: $DNS2 ${NOCOLOR}"
   echo -ne "\n${CYAN}------------------------------------${NOCOLOR}\n"
   echo -ne "\n${GREEN}Confirm whether the above details are correct(${BLINKING}${RED}yes/no${NOCOLOR}): "
   read condition1
   echo -ne "\n${BLUE}Configuring the Static IP - $IP_ADDRESS on the interface $INTERFACE ${NOCOLOR} "
   # Check the confirmation and proceed further
   case $condition1 in
   [yY][Ee][Ss])
   # Backup the current interfaces file
   date_var=`date "+%Y-%m-%d-%T"`
   cp /etc/network/interfaces /etc/network/interfaces.bak-${date_var}
   # Configure the network interface
   > /etc/network/interfaces
  cat <<EOF >> /etc/network/interfaces
  # This file describes the network interfaces available on your system
  # and how to activate them. For more information, see interfaces(5).

      source /etc/network/interfaces.d/*
    
    # The loopback network interface
    auto lo
    
    # The primary network interface
    iface lo inet loopback
    auto $INTERFACE
    iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS1 $DNS2
    EOF

   # Restart the networking service to apply changes
   systemctl restart networking
   # Display the new network configuration
   echo -ne "\n\n${CYAN}Configured the Static IP - $IP_ADDRESS on the interface $INTERFACE ${NOCOLOR} "
   echo -ne "\n\n${YELLOW}These are the IP details:${NOCOLOR}\n"
   echo -ne "\n${CYAN}------------------------------------${NOCOLOR}\n"
   ip addr show $INTERFACE
   echo -ne "\n${CYAN}------------------------------------${NOCOLOR}\n"
   echo -ne "\n${GREEN}Taken the network configuration backup as - /etc/network/interfaces.bak-${date_var}\n"
   echo -ne "\n${GREEN}If you need any additional configuration, feel free to modify using the config file - /etc/network/interfaces\n${NOCOLOR}"
   ;;

   *) echo "Invalid input"
            ;;
   esac
}

if [ $# -eq 0 ] || [[ "$1" == "--multi-node-deployment" ]]; then
  echo -e "\n${GREEN}Entering to the default multi-node installation mode...${NOCOLOR}"
  freeavailabledisk || exit 1
  cephalreadythere  || exit 1
  if [ -f /etc/debian_version ]
  then
      echo -e "\n${GREEN}Proceeding for ceph initial deployment for debian${NOCOLOR}\n"
      debian_prerequsites
      debian_update
      debian_cephadm
      multi_node_deployment
  else
    echo -e "${RED}This script is designied for debian based distributions\nSince this machine is not a Debian-based distribution, exiting from  further execution${NOCOLOR}\n" 1>&2 exit 1
  fi
else
case "$1" in
  staticip)
  staticipset ;;
 --single-node-deployment)
  echo -e "\n${GREEN}Starting single-node installation mode...${NOCOLOR}"
  freeavailabledisk || exit 1
  cephalreadythere  || exit 1
#  if [ -f /etc/debian_version ]
#  then
      echo -e "\n${GREEN}Proceeding for ceph initial deployment for debian${NOCOLOR}\n"
      debian_prerequsites
      debian_update
      debian_cephadm
      single_node_deployment
#  else
#    echo -e "${RED}This script is designed for debian based distributions\nSince this machine is not a Debian-based distribution, exiting from  further execution${NOCOLOR>
#  fi
 ;;
  --setup-rgw)
     echo -e "\n${GREEN}Deploying RGW/S3 on this node..${NOCOLOR}"
      rgwPrerequsites
      rgwDeployment
      rgwUser
      gets3User ;;
  --install-ente-photos)
   enteapp_install ;;
# echo -e "\n${GREEN}This feature is not available at this stage, the feature enhancement Work in progress to integrate with enteapp..${NOCOLOR}";;
  --purge)
     cephpurgenode ;;
  --disk-check)
     echo -e "\n${GREEN}Executing the precheck..${NOCOLOR}"
     echo -e "\n${GREEN}Checking for free disk..${NOCOLOR}"
     freeavailabledisk
          ;;
  *)
     echo -e "\nUsage: $0 --option [multi-node-deployment|single-node-deployment|install-ente-photos|setup-rgw]
\n Options: \n
   --multi-node-deployment${NOCOLOR}    Install multi-node Ceph cluster(default mode)
   --single-node-deployment${NOCOLOR}   Install  single node Ceph cluster
   --setup-rgw${NOCOLOR}                Deploy rgw/s3 on the node
   --install-ente-photos${NOCOLOR}      Install Ente Photo app and integrate with Ceph cluster
   --purge${NOCOLOR}                    Purge/delete the Ceph cluster
   --staticip${NOCOLOR}                 Set  static ip address to the machine
   --disk-check${NOCOLOR}               Check whether any free disks(without partition or filesystem) are available" ;;
esac

fi
