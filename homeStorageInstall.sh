#!/bin/bash

# This script is to deploy s3 compatable rgw
# usage "bash homeStorageInstall.sh"

# initial check
if [ "$(id -u)" != "0" ]
then
  echo "This script must be run as root" 1>&2 exit 1
fi

#Declare variables
cephadm_location="https://download.ceph.com/rpm-reef/el9/noarch/cephadm"
ceph_version="18.2.4"
container_image="quay.io/ceph/ceph:v18.2.4"
get_pvt_ipaddress=`hostname -I | awk '{print $1}'`
get_public_ipaddress=`curl -s https://icanhazip.com`
realm_name=test_realm
zonegroup_name=default
zone_name=test_zone
rgw_placement=`hostname -s`
rgw_user=s3user

# Define functions
function debin_update() {
  echo "Updating package lists..."
  sudo apt update
  echo "Upgrading packages..."
  sudo apt upgrade -y
  echo "Running full distribution upgrade..."
  sudo apt full-upgrade -y
  echo "Cleaning up unnecessary packages..."
  sudo apt autoremove -y
  sudo apt autoclean
  echo "System update complete."
}

function debin_prerequsites() {
  echo "Installing podman, lvm2, chrony..."
  sudo apt update
  sudo apt install -y lvm2 podman chrony
}

function debin_cephadm() {
  echo "configuring cephadm..."
  cd /sbin/ && curl -# --remote-name --location "${cephadm_location}"
  chmod +x /sbin/cephadm
  /sbin/cephadm add-repo --version "${ceph_version}"
}

function singleHostDeployment() {
  echo "cephadm deployment is going on..."
  podman pull "${container_image}"
  cephadm --image "${container_image}" bootstrap --mon-ip "${get_pvt_ipaddress}"  --single-host-defaults | tee /root/ceph_install.out
  cephadm shell -- ceph status
  sleep 60
  cephadm install ceph-common
  echo "Started OSD deployment..."
  ceph orch apply osd --all-available-devices
  sleep 60
  cephadm shell -- ceph orch ps --daemon_type osd
  ceph config set global mon_allow_pool_delete true
  ceph config set global osd_pool_default_min_size 1
  ceph config set global osd_pool_default_size 1
}

function rgwPrerequsites() {
  echo "Configuring realm..."
  radosgw-admin realm create --rgw-realm="${realm_name}" --default
  echo "Configuring zonegroup..."
  radosgw-admin zonegroup create --rgw-zonegroup="${zonegroup_name}" --master --default
  echo "Configuring zone..."
  radosgw-admin zone create --rgw-zonegroup="${zonegroup_name}" --rgw-zone="${zone_name}" --master --default
  echo "Performing period update..."
  radosgw-admin period update --rgw-realm="${realm_name}" --commit
}

function rgwDeployment() {
  echo "Deploying rgw..."
  ceph orch apply rgw myhomergw --realm="${realm_name}" --zone="${zone_name}" --placement="1 $(rgw_placement)"
}

function rgwUser() {
  echo "Creating rgw user..."
  radosgw-admin user create --uid="${rgw_user}" --display-name="S3 user" --email="s3user@example.com"
}
function gets3User() {
  echo "Details to configure s3cmd/aws cli/any other s3 client..."
  apt update
  apt install -y s3cmd jq
  ACCESS_KEY=`radosgw-admin user info --uid="${rgw_user}" | jq  -r '.keys[0].access_key'`
  SECRET_KEY=`radosgw-admin user info --uid="${rgw_user}" | jq  -r '.keys[0].secret_key'`
  ENDPOINT="${get_pvt_ipaddress}":80
  echo "Access Key: $ACCESS_KEY"
  echo "Secret Key: $SECRET_KEY"
  echo "Endpoint Details(from the node): $ENDPOINT"
  echo "Feel free to configure your fevorate s3 client.."
#  s3cmd mb s3:///homebucket
}

if [ -f /etc/debian_version ]
then
    debin_update
    debin_prerequsites
    debin_cephadm
    singleHostDeployment
    rgwPrerequsites
    rgwDeployment
    rgwUser
    gets3User
else
    echo "This is not a Debian-based distribution."
fi
