#!/bin/bash -e

#Parameters to configure
export JCS_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export JCS_SECRET_KEY=yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
logfile=$(date +"%m_%d_%Y").txt
VPCENDPOINT="vpc.ind-west-1.internal.jiocloudservices.com"
COMENDPOINT="compute.ind-west-1.internal.jiocloudservices.com"
iter=0
#Check for environment
#if [[ -z "$OS_AUTH_URL" || -z "$OS_USERNAME" || -z "$OS_PASSWORD" || -z "$OS_TENANT_NAME" ]]; then
#    echo "Please set OS_AUTH_URL, OS_USERNAME, OS_PASSWORD and OS_TENANT_NAME"
#    exit 1
#fi


#### utilities functions merged from devstack to check required parameter is not empty
# Prints line number and "message" in error format
# err $LINENO "message"


function err() {
    local exitcode=$?
    errXTRACE=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[ERROR] ${BASH_SOURCE[2]}:$1 $2"
#    echo $msg 1>&2;
    #if [[ -n ${SCREEN_LOGDIR} ]]; then
        #echo $msg >> "${SCREEN_LOGDIR}/error.log"
    #fi
    $errXTRACE
    return $exitcode
}
# Prints backtrace info
# filename:lineno:function
function backtrace {
    local level=$1
    local deep=$((${#BASH_SOURCE[@]} - 1))
#    echo "[Call Trace]"
    while [ $level -le $deep ]; do
        #echo "${BASH_SOURCE[$deep]}:${BASH_LINENO[$deep-1]}:${FUNCNAME[$deep-1]}"
        deep=$((deep - 1))
    done
}


# Prints line number and "message" then exits
# die $LINENO "message"
function die() {
    local exitcode=$?
    set +o xtrace
    local line=$1; shift
    if [ $exitcode == 0 ]; then
        exitcode=1
    fi
    backtrace 2
    err $line "$*" $evar 
    exit $exitcode
}


# Checks an environment variable is not set or has length 0 OR if the
# exit code is non-zero and prints "message" and exits
# NOTE: env-var is the variable name without a '$'
# die_if_not_set $LINENO env-var "message"
function die_if_not_set() {
    local exitcode=$?
    FXTRACE=$(set +o | grep xtrace)
    set +o xtrace
    local line=$1; shift
    local evar=$1; shift
    if ! is_set $evar || [ $exitcode != 0 ]; then
        echo "2 $evar" 1>&2;
        die $line "$*"
    fi
    $FXTRACE
}

# Test if the named environment variable is set and not zero length
# is_set env-var
function is_set() {
    local var=\$"$1"
    eval "[ -n \"$var\" ]" # For ex.: sh -c "[ -n \"$var\" ]" would be better, but several exercises depends on this
}

#######################################

createVpc() {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=CreateVpc&CidrBlock=192.168.0.0/16&Version=2015-10-01") | source /dev/stdin)
    echo $resp > $logfile
    #resp="<CreateVpcResponse xmlns=http://$VPCENDPOINT/doc/2015-10-01/> <requestId>req-725d1c36-ff69-4a64-988c-6dcb6815ed12</requestId> <vpc> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <cidrBlock>192.168.0.0/16</cidrBlock> <isDefault>false</isDefault> <dhcpOptionsId>default</dhcpOptionsId> </vpc> </CreateVpcResponse>"
    regex="<vpcId>(.*)</vpcId>"
    if [[ $resp =~ $regex ]]; then
        VPCID="${BASH_REMATCH[1]}" 
    fi
    die_if_not_set $LINENO $VPCID "CreateVpc - Fail to create VPC"
    echo "0 CreateVpc - Successfully Created Vpc"

}



describeVpc() {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DescribeVpcs&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<DescribeVpcsResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-a0481a19-3457-40be-bd94-1cac467f0076</requestId> <vpcSet> <item> <state>available</state> <vpcId>vpc-2528cb8d</vpcId> <cidrBlock>10.0.0.0/24</cidrBlock> <isDefault>false</isDefault> <dhcpOptionsId>default</dhcpOptionsId> </item> <item> <state>available</state> <vpcId>vpc-33ca30bf</vpcId> <cidrBlock>10.168.0.0/16</cidrBlock> <isDefault>false</isDefault> <dhcpOptionsId>default</dhcpOptionsId> </item> <item> <state>available</state> <vpcId>vpc-bb935f32</vpcId> <cidrBlock>192.168.0.0/16</cidrBlock> <isDefault>false</isDefault> <dhcpOptionsId>default</dhcpOptionsId> </item> <item> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <cidrBlock>192.168.0.0/16</cidrBlock> <isDefault>false</isDefault> <dhcpOptionsId>default</dhcpOptionsId> </item> </vpcSet> </DescribeVpcsResponse>"
    regex="($VPCID)"
    if [[ $resp =~ $regex ]]; then
        VPCIDcheck="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $VPCIDcheck "DescribeVpc - Fail to describe VPC"
    echo "0 DescribeVpc - Successfully Described Vpc"    

}

createSubnet() {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=CreateSubnet&VpcId=$VPCID&CidrBlock=192.168.1.0/24&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://vpc.ind-west0.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="<subnetId>(.*)</subnetId>"
    if [[ $resp =~ $regex ]]; then
        SUBNETID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SUBNETID "CreateSubnet - Fail to create Subnet"
    echo "0 CreateSubnet - Successfully Created Subnet"    

}

describeSubnet() {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DescribeSubnets&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="($SUBNETID)"
    if [[ $resp =~ $regex ]]; then
        SUBNETIDCheck="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SUBNETIDCheck "DescribeSubnet - Fail to describe Subnet"
    echo "0 DescribeSubnet - Successfully Described Subnet"    


}

createSecurityGroup() {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=CreateSecurityGroup&GroupName=TestScript&GroupDescription=Automated_Group&VpcId=$VPCID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSecurityGroupResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-134f3410-8ccc-481e-9f42-7644bdac1e93</requestId> <return>true</return> <groupId>sg-2280f124</groupId> </CreateSecurityGroupResponse>"
    regex="<groupId>(.*)</groupId>"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUP="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUP "CreateSecurityGroup - Fail to create SecurityGroup"
    echo "0 CreateSecurityGroup - Successfully Created Security Group"    

}


createSecurityGroupRules() {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=AuthorizeSecurityGroupIngress&GroupId=$SECURITYGROUP&IpPermissions.1.IpProtocol=tcp&IpPermissions.1.FromPort=22&IpPermissions.1.ToPort=22&IpPermissions.1.IpRanges.1.CidrIP=0.0.0.0/0&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<AuthorizeSecurityGroupIngressResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-d54ec7a7-201f-4f7a-88b0-b1bdcf9fe6e0</requestId> <return>true</return> </AuthorizeSecurityGroupIngressResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUPRULEIN="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUPRULEIN "CreateSecurityGroupRules - Fail to create SecurityGroupRule - Ingress"



    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=AuthorizeSecurityGroupIngress&GroupId=$SECURITYGROUP&IpPermissions.1.IpProtocol=icmp&IpPermissions.1.FromPort=-1&IpPermissions.1.ToPort=-1&IpPermissions.1.IpRanges.1.CidrIP=0.0.0.0/0&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<AuthorizeSecurityGroupIngressResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-d54ec7a7-201f-4f7a-88b0-b1bdcf9fe6e0</requestId> <return>true</return> </AuthorizeSecurityGroupIngressResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUPRULEIN="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUPRULEIN "CreateSecurityGroupRules - Fail to create SecurityGroupRule - Ingress"




    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=AuthorizeSecurityGroupEgress&GroupId=$SECURITYGROUP&IpPermissions.1.IpProtocol=tcp&IpPermissions.1.FromPort=22&IpPermissions.1.ToPort=22&IpPermissions.1.IpRanges.1.CidrIP=0.0.0.0/0&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUPRULEOUT="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUPRULEOUT "CreateSecurityGroupRules - Fail to create SecurityGroupRule - Egress"



    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=RevokeSecurityGroupIngress&GroupId=$SECURITYGROUP&IpPermissions.1.IpProtocol=tcp&IpPermissions.1.FromPort=22&IpPermissions.1.ToPort=22&IpPermissions.1.IpRanges.1.CidrIP=0.0.0.0/0&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    # resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        REVSECURITYGROUPRULEIN="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $REVSECURITYGROUPRULEIN "Fail to remove SecurityGroupRule - Ingress"


    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=RevokeSecurityGroupIngress&GroupId=$SECURITYGROUP&IpPermissions.1.IpProtocol=icmp&IpPermissions.1.FromPort=0&IpPermissions.1.ToPort=65535&IpPermissions.1.IpRanges.1.CidrIP=0.0.0.0/0&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        REVSECURITYGROUPRULEOUT="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $REVSECURITYGROUPRULEOUT "Fail to create SecurityGroupRule - Ingress - ICMP"


    echo "0 CreateSecurityGroupRules - Successfully Created/Deleted Security Group Rules"    


}


describeSeucrityGroup() {

    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DescribeSecurityGroups&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="($SECURITYGROUP)"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUPIDCheck="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUPIDCheck "DescribeSeucrityGroup - Fail to describe Security Group"
    echo "0 DescribeSeucrityGroup - Successfully Described SecurityGroup" 

}


deleteSecurityGroup() {

    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DeleteSecurityGroup&GroupId=$SECURITYGROUP&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUPDELETE="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUPDELETE "DeleteSecurityGroup - Fail to delete Security Group -- DO IT MANUALLY"
    echo "0 DeleteSecurityGroup - Successfully Deleted SecurityGroup" 

}

deleteSubnet() {

    #while [[ $iter -lt 5 ]]; do
        resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DeleteSubnet&SubnetId=$SUBNETID&Version=2015-10-01") | source /dev/stdin)
        echo $resp >> $logfile
        #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
        regex="(>true<)"
        if [[ $resp =~ $regex ]]; then
            SUBNETDELETE="${BASH_REMATCH[1]}"
        fi
    #    if [[ is_set $SUBNETDELETE - ]] ; then
    #        break
    #    fi
    #    ((iter++)) 
    #    echo "retrying delete Subnet..."
    #    sleep 300
    #done  
    die_if_not_set $LINENO $SUBNETDELETE "DeleteSubnet - Fail to delete Subnet -- DO IT MANUALLY"
    echo "0 DeleteSubnet - Successfully Deleted Subnet" 

}


deleteVpc () {

    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DeleteVpc&VpcId=$VPCID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        VPCDELETE="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $VPCDELETE "DeleteVpc - Fail to delete VPC -- DO IT MANUALLY"
    echo "0 DeleteVpc - Successfully Deleted VPC" 


}

terminateInstance () {
    resp=$(echo $(vpcclient "https://$COMENDPOINT/?Action=TerminateInstances&InstanceId.1=$INSTANCEID&Version=2016-03-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(<currentState>shutting-down</currentState>)"
    if [[ $resp =~ $regex ]]; then
        TERMINATIONID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $TERMINATIONID "TerminateInstance - Fail to terminate instance -- DO IT MANUALLY"
    echo "0 TerminateInstance - Successfully terminated instance" 


}




runInstance () {
    resp=$(echo $(vpcclient "https://$COMENDPOINT/?Action=RunInstances&SubnetId=$SUBNETID&ImageId=ami-01184524&InstanceTypeId=c1.small&Version=2016-03-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="<instanceId>(.*)</instanceId>"
    if [[ $resp =~ $regex ]]; then
        INSTANCEID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $INSTANCEID "RunInstance - Fail to run Instance VPC -- DO IT MANUALLY"
    echo "0 RunInstance - Successfully createdInstance VPC" 


}



allocateAddress () {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=AllocateAddress&Domain=vpc&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="<allocationId>(.*)</allocationId>"
    if [[ $resp =~ $regex ]]; then
        ALLOCATIONID="${BASH_REMATCH[1]}"
    fi
    regex="<publicIp>(.*)</publicIp>"
    if [[ $resp =~ $regex ]]; then
        PUBLICIP="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $ALLOCATIONID "AllocateAddress - Fail to Allocate address"
    echo "0 AllocateAddress - Successfully Allocated address" 


}

associateAddress () {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=AssociateAddress&AllocationId=$ALLOCATIONID&InstanceId=$INSTANCEID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="<associationId>(.*)</associationId>"
    if [[ $resp =~ $regex ]]; then
        ASSOCIATIONID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $ASSOCIATIONID "AssociateAddress - Fail to associate address"
    echo "0 AssociateAddress - Successfully associate address" 

}


describeAddresses() {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DescribeAddresses&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="($ASSOCIATIONID)"
    if [[ $resp =~ $regex ]]; then
        DESCRIBEADD1="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $DESCRIBEADD1 "DescribeAddresses - Fail to describe address"
    echo "0 DescribeAddresses - Successfully describe address" 

}

disassociateAddress () {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DisassociateAddress&AssociationId=$ASSOCIATIONID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        DISASSOCIATIONID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $DISASSOCIATIONID "DisassociateAddress - Fail to disassociate address"
    echo "0 DisassociateAddress - Successfully disassociated address" 


}

releaseAddress () {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=ReleaseAddress&AllocationId=$ALLOCATIONID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        RELEASEID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $RELEASEID "ReleaseAddress - Fail to release address"
    echo "0 ReleaseAddress - Successfully released address" 


}

createRouteTable () {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=CreateRouteTable&VpcId=$VPCID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="<routeTableId>(.*)</routeTableId>"
    if [[ $resp =~ $regex ]]; then
        RTBID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $RTBID "CreateRouteTable - Fail to createRouteTable"
    echo "0 CreateRouteTable - Successfully Created RouteTable" 
}


createRoute () {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=CreateRoute&RouteTableId=$RTBID&InstanceId=$INSTANCEID&DestinationCidrBlock=11.11.11.11/32&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        RT="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $RT "CreateRoute - Fail to createRoute"
    echo "0 CreateRoute - Successfully Added Route" 
}

associateRouteTable () {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=AssociateRouteTable&SubnetId=$SUBNETID&RouteTableId=$RTBID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="<associationId>(.*)</associationId>"
    if [[ $resp =~ $regex ]]; then
        ASSOCRTBID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $ASSOCRTBID "AssociateRouteTable - Fail to associate RouteTable"
    echo "0 AssociateRouteTable - Successfully Associated RouteTable" 
}


describeRouteTables () {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DescribeRouteTables&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="($RTBID)"
    if [[ $resp =~ $regex ]]; then
        CHECKRTBID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $CHECKRTBID "DescribeRouteTables - Fail to describe RouteTable"
    echo "0 DescribeRouteTables - Successfully Described RouteTable" 
}

disassociateRouteTable () {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DisassociateRouteTable&AssociationId=$ASSOCRTBID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        DISASSOCRTBID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $DISASSOCRTBID "DisassociateRouteTable - Fail to diassociate RouteTable"
    echo "0 DisassociateRouteTable - Successfully disassociated RouteTable" 
}

deleteRouteTable () {
    resp=$(echo $(vpcclient "https://$VPCENDPOINT/?Action=DeleteRouteTable&RouteTableId=$RTBID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> $logfile
    #resp="<CreateSubnetResponse xmlns="http://$VPCENDPOINT/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        DISASSOCRTBID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $DISASSOCRTBID "DeleteRouteTable - Fail to diassociate RouteTable"
    echo "0 DeleteRouteTable - Successfully disassociated RouteTable" 
}

describeInstances() {
    resp=$(echo $(vpcclient "https://$COMENDPOINT/?Action=DescribeInstances&Version=2016-03-01") | source /dev/stdin)
    echo $resp >> $logfile
}


createVpc
describeVpc

createSubnet
describeSubnet

createSecurityGroup
createSecurityGroupRules
describeSeucrityGroup

runInstance
allocateAddress
associateAddress
describeAddresses

createRouteTable
createRoute
describeRouteTables
associateRouteTable
disassociateRouteTable
deleteRouteTable

disassociateAddress
releaseAddress
#sleep 15
terminateInstance
#sleep 30
deleteSecurityGroup
sleep 15
describeInstances
deleteSubnet
deleteVpc

echo "[PASS]"
