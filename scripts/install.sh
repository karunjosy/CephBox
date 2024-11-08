#!/bin/bash

# This script is to deploy s3 compatable rgw
# usage "bash install.sh"

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

### Define functions
# Adding condition to check whether the cluster is already installed or not
function cephalreadythere() {
    ceph_fsid=$(cephadm shell -- ceph fsid 2> /dev/null)
    if [ "$?" -eq 0 ]; then
        echo -e "\n${RED}This node already has a ceph cluster with cluster ID:${NOCOLOR} $ceph_fsid.\nSo Dropping the default installation"
        echo -e "\n${BLUE}Please review the cluster ${RED} $ceph_fsid ${NOCOLOR} and proceed further. For more options: execute the command ${YELLOW}bash install.sh --help${NOCOLOR}\n" 1>&2 exit 1
        exit 1
    fi
}

# Adding condition whether any free disks are available or not
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

# debin prerequsites
function debin_prerequsites() {
  echo -e "${GREEN}Installing podman, lvm2, chrony...${NOCOLOR}\n"
  sudo apt update
  sudo apt install -y lvm2 podman chrony sudo curl
}

# debin package update
function debin_update() {
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

# debin cephadm binary setting
function debin_cephadm() {
  echo -e "${GREEN}configuring cephadm...${NOCOLOR}\n"
  cd /sbin/ && curl -# --remote-name --location "${cephadm_location}"
  chmod +x /sbin/cephadm
  /sbin/cephadm add-repo --version "${ceph_version}"
  echo "export PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/sbin:/usr/local/bin" >> ~/.bashrc
  source ~/.bashrc
}

# debin install ceph using cephadm 
function singleHostDeployment() {
  echo -e "${GREEN}cephadm deployment is going on...${NOCOLOR}\n"
  podman pull "${container_image}"
  cephadm --image "${container_image}" bootstrap --mon-ip "${get_pvt_ipaddress}" --initial-dashboard-user "${dashboard_user}" --initial-dashboard-password "${dashboard_password}" --single-host-defaults | tee /root/ceph_install.out
  cephadm shell -- ceph status
  echo -e "${GREEN}Started OSD deployment, it may take some time...${NOCOLOR}\n"
  sleep 30
  cephadm shell -- ceph orch apply osd --all-available-devices
  sleep 30
  cephadm shell -- ceph config set mgr mgr/cephadm/container_image_grafana "${grafana_image}"
  sleep 5
  cephadm shell -- ceph mgr fail
  echo -e "${GREEN}Checking the running OSD services...${NOCOLOR}\n"
  cephadm shell -- ceph orch ps --daemon_type osd
  echo -e "${GREEN}Setting some additional parameters...${NOCOLOR}\n"
  cephadm shell -- ceph config set global mon_allow_pool_delete true
  cephadm shell -- ceph config set global osd_pool_default_min_size 1
  cephadm shell -- ceph config set global osd_pool_default_size 1
  echo -e "${GREEN}Deployment got completed...please review the below: ${NOCOLOR}\n"
  cephadm shell -- ceph -s
  cephadm shell -- ceph orch ls
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
}

# Fetching rgw user
function gets3User() {
  echo -e "${GREEN}Details to configure s3cmd/aws cli/any other s3 client...${NOCOLOR}\n"
  apt update
  apt install -y s3cmd jq
  ACCESS_KEY=`cephadm shell -- radosgw-admin user info --uid="${rgw_user}" | jq  -r '.keys[0].access_key'`
  SECRET_KEY=`cephadm shell -- radosgw-admin user info --uid="${rgw_user}" | jq  -r '.keys[0].secret_key'`
  ENDPOINT="${get_pvt_ipaddress}":80
  echo -e "${GREEN}Access Key:${NOCOLOR} $ACCESS_KEY"
  echo -e "${GREEN}Secret Key:${NOCOLOR} $SECRET_KEY"
  echo -e "${GREEN}Endpoint Details(from the node):${NOCOLOR} $ENDPOINT"
  echo -e "${GREEN}Feel free to configure your fevorate s3 client..${NOCOLOR}\n"
#  s3cmd mb s3:///homebucket
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

if [[ $# -eq 0 ]] ; then
  echo -e "\n${GREEN}Entering to the default installation mode...${NOCOLOR}"
  freeavailabledisk || exit 1
  cephalreadythere  || exit 1
  if [ -f /etc/debian_version ]
  then
      echo -e "\n${GREEN}Proceeding for ceph initial deployment for debian${NOCOLOR}\n"
      debin_prerequsites
      debin_update
      debin_cephadm
      singleHostDeployment
  else
    echo -e "${RED}This script is designied for debian based distributions\nSince this machine is not a Debian-based distribution, Dropping the script from the further execution...${NOCOLOR}\n" 1>&2 exit 1
  fi
else
case "$1" in
  staticip)
  staticipset ;;
  rgw)
     echo -e "\n${GREEN}Deploying RGW/S3 on this node..${NOCOLOR}"
      rgwPrerequsites
      rgwDeployment
      rgwUser
      gets3User ;;
  enteapp)
     echo -e "\n${GREEN}This feature is not available at this stage, the feature enhancement Work in progress to integrate with enteapp..${NOCOLOR}";;
  purge)
     cephpurgenode ;;
  diskcheck)
     echo -e "\n${GREEN}Executing the precheck..${NOCOLOR}"
     echo -e "\n${GREEN}Checking for free disk..${NOCOLOR}"
     freeavailabledisk 
          ;;
  *)
     echo -e "\n${GREEN}The avaliable options are: \n   ${YELLOW}bash install.sh${NOCOLOR} - Run the script without any argument is for default ceph installation without rgw/s3.\n   ${YELLOW}"rgw"${NOCOLOR} - This argument is to deploy rgw/s3 on this machine.\n   ${YELLOW}"enteapp"${NOCOLOR} - This argument is to integrate with ente app.\n   ${YELLOW}"purge"${NOCOLOR} - This argument is to purge/delete the cluster.\n   ${YELLOW}"staticip"${NOCOLOR} - This argument is to set the static ip address to the machine.\n   ${YELLOW}"diskcheck"${NOCOLOR} - This argument is to check whether any free disks(without partition or filesystem) are available on this machine." ;;
esac

fi
