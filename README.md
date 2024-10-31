# CephDrive

Repository for backend api

#### Single node CephDrive

- **Prerequesites**:
  
  a. Repository for backend debian_version: 12.7
  
  b. Atleast one free disk
  
  c. Internet access to the node.
  
  d. Root access.

- **Steps**:
- 
  i.   Download the script - `scripts/install.sh` to the home directory of the `root` user - `/root`.
  
  ii.  Give execute permission: `chmod +x install.sh`

  iii. Run the script and follow the instructions: `bash install.sh`

- **Customization**

The below variables /  can be done on the script:
~~~
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
~~~
