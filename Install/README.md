# Intro

Linux, if you think about it, is one of the most complex engineering software system in the world. And we have thousands of Linux admins to manage linux environments. However, we have billions of people using Android phone every minute of their life without knowing what happens in the background. In regards to the installation and management of CephBox, our philosophy is the same. Ceph is a complex distributed storage system. But the end user doesn't need to know that!

CephBox in it's actuality should behave as a Storage appliance. You buy it, connect to the power, and start using it. But that's a long way to go...

In the meantime, if anyone wants to try this on their machine, be it may Raspberry Pi or a full fledged Server, you can follow the doc [here](https://karunjosy.github.io/docs/category/DIY)

We are in the process of automating the installation of different components as much as possible. You will find some bach scripts in this folder to help with that.


## Single node installation

**Prerequesites**:
  
    a. Repository for backend debian_version: 12.7
  
    b. Atleast one free disk
  
    c. Internet access to the node.
  
    d. Root access.

**Steps**:

 *Option 1 : Using git clone*
 
  i. Login as root user and clone repository using the command `git clone https://github.com/karunjosy/CephBox.git` to the home directory of the `root` user - `/root`.
  
  ii.  Go inside the directory `CephBox/install/`(`cd CephBox/install`) and give execute permission: `chmod +x install.sh`

  iii. Run the command - `bash install.sh` to setup basic ceph enviroment without s3 endpoint.
  iv.  If you wish to deploy RGW then after installation run the script again with 'rgw' switch :  `bash install.sh rgw`

*Option 2 : Downloading the script*
From the terminal run:
  ```
  curl -sSL https://raw.githubusercontent.com/karunjosy/CephBox/refs/heads/main/Install/install.sh| bash
  Or to deploy RGW
  bash <(curl -sSL https://raw.githubusercontent.com/karunjosy/CephBox/refs/heads/main/scripts/install.sh) rgw
  ```

**Customization**

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

Additional options within the script
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
