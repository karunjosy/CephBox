# CephDrive

Repository for backend api

#### Single node CephDrive

- **Prerequesites**:
  
  a. Repository for backend debian_version: 12.7
  
  b. Atleast one free disk
  
  c. Internet access to the node.
  
  d. Root access.

- **Steps**:
 
  i. Login as root user and clone repository using the command `git clone https://github.com/karunjosy/CephDrive.git` to the home directory of the `root` user - `/root`.
  
  ii.  Go inside the directory `CephDrive/scripts`(`cd CephDrive/scripts`) and give execute permission: `chmod +x install.sh`

  iii. Run the command - `bash install.sh` to setup basic ceph enviroment without s3 endpoint.
  iv.  Run the command - `bash install.sh rgw` to setup the rgw/s3 enviroment.

- **Customization**

The below variables can be customize from the script based on the needs:
~~~
cephadm_location="https://download.ceph.com/rpm-squid/el9/noarch/cephadm"
ceph_version="19.2.0"
container_image="quay.io/ceph/ceph:v19.2.0"
grafana_image="quay.io/ceph/ceph-grafana:9.4.12"
get_pvt_ipaddress=`hostname -I | awk '{print $1}'`
realm_name=test_realm
zonegroup_name=default
zone_name=test_zone
rgw_placement=`hostname -s`
rgw_user=s3user
dashboard_user=admin
dashboard_password=admin
~~~

- Additional options whithin the script
~~~
# bash install.sh --help

The avaliable options are:
   bash install.sh - Run the script without any argument is for default ceph installation without rgw/s3.
   rgw - This argument is to deploy rgw/s3 on this machine.
   enteapp - This argument is to integrate with ente app.
   purge - This argument is to purge/delete the cluster.
   staticip - This argument is to set the static ip address to the machine.
   diskcheck - This argument is to check whether any free disks(without partition or filesystem) are available on this machine.
~~~
