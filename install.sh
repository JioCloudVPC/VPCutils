#!/bin/bash -e

#Parameters to configure
export JCS_ACCESS_KEY=1b0b5129b0fb47d393ca3d1ab76d6059
export JCS_SECRET_KEY=be14df3237f94bd3b73ced73a35a6515 

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
    echo $msg 1>&2;
    if [[ -n ${SCREEN_LOGDIR} ]]; then
        echo $msg >> "${SCREEN_LOGDIR}/error.log"
    fi
    $errXTRACE
    return $exitcode
}
# Prints backtrace info
# filename:lineno:function
function backtrace {
    local level=$1
    local deep=$((${#BASH_SOURCE[@]} - 1))
    echo "[Call Trace]"
    while [ $level -le $deep ]; do
        echo "${BASH_SOURCE[$deep]}:${BASH_LINENO[$deep-1]}:${FUNCNAME[$deep-1]}"
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
        echo $evar 1>&2;
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
    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=CreateVpc&CidrBlock=192.168.0.0/16&Version=2015-10-01") | source /dev/stdin)
    echo $resp > test.log
    #resp="<CreateVpcResponse xmlns=http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/> <requestId>req-725d1c36-ff69-4a64-988c-6dcb6815ed12</requestId> <vpc> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <cidrBlock>192.168.0.0/16</cidrBlock> <isDefault>false</isDefault> <dhcpOptionsId>default</dhcpOptionsId> </vpc> </CreateVpcResponse>"
    regex="<vpcId>(.*)</vpcId>"
    if [[ $resp =~ $regex ]]; then
        VPCID="${BASH_REMATCH[1]}" 
    fi
    die_if_not_set $LINENO $VPCID "Fail to create VPC"
    echo "Successfully Created Vpc"

}



describeVpc() {
    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=DescribeVpcs&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> test.log
    #resp="<DescribeVpcsResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-a0481a19-3457-40be-bd94-1cac467f0076</requestId> <vpcSet> <item> <state>available</state> <vpcId>vpc-2528cb8d</vpcId> <cidrBlock>10.0.0.0/24</cidrBlock> <isDefault>false</isDefault> <dhcpOptionsId>default</dhcpOptionsId> </item> <item> <state>available</state> <vpcId>vpc-33ca30bf</vpcId> <cidrBlock>10.168.0.0/16</cidrBlock> <isDefault>false</isDefault> <dhcpOptionsId>default</dhcpOptionsId> </item> <item> <state>available</state> <vpcId>vpc-bb935f32</vpcId> <cidrBlock>192.168.0.0/16</cidrBlock> <isDefault>false</isDefault> <dhcpOptionsId>default</dhcpOptionsId> </item> <item> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <cidrBlock>192.168.0.0/16</cidrBlock> <isDefault>false</isDefault> <dhcpOptionsId>default</dhcpOptionsId> </item> </vpcSet> </DescribeVpcsResponse>"
    regex="($VPCID)"
    if [[ $resp =~ $regex ]]; then
        VPCIDcheck="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $VPCIDcheck "Fail to describe VPC"
    echo "Successfully Described Vpc"    

}

createSubnet() {
    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=CreateSubnet&VpcId=$VPCID&CidrBlock=192.168.1.0/24&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> test.log
    #resp="<CreateSubnetResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="<subnetId>(.*)</subnetId>"
    if [[ $resp =~ $regex ]]; then
        SUBNETID="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SUBNETID "Fail to create Subnet"
    echo "Successfully Created Subnet"    

}

describeSubnet() {
    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=DescribeSubnets&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> test.log
    #resp="<CreateSubnetResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="($SUBNETID)"
    if [[ $resp =~ $regex ]]; then
        SUBNETIDCheck="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SUBNETIDCheck "Fail to describe Subnet"
    echo "Successfully Described Subnet"    


}

createSecurityGroup() {
    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=CreateSecurityGroup&GroupName=TestScript&GroupDescription=Automated_Group&VpcId=$VPCID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> test.log
    #resp="<CreateSecurityGroupResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-134f3410-8ccc-481e-9f42-7644bdac1e93</requestId> <return>true</return> <groupId>sg-2280f124</groupId> </CreateSecurityGroupResponse>"
    regex="<groupId>(.*)</groupId>"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUP="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUP "Fail to create SecurityGroup"
    echo "Successfully Created Security Group"    

}


createSecurityGroupRules() {
    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=AuthorizeSecurityGroupIngress&GroupId=$SECURITYGROUP&IpPermissions.1.IpProtocol=tcp&IpPermissions.1.FromPort=22&IpPermissions.1.ToPort=22&IpPermissions.1.IpRanges.1.CidrIP=0.0.0.0/0&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> test.log
    #resp="<AuthorizeSecurityGroupIngressResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-d54ec7a7-201f-4f7a-88b0-b1bdcf9fe6e0</requestId> <return>true</return> </AuthorizeSecurityGroupIngressResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUPRULEIN="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUPRULEIN "Fail to create SecurityGroupRule - Ingress"



    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=AuthorizeSecurityGroupEgress&GroupId=$SECURITYGROUP&IpPermissions.1.IpProtocol=tcp&IpPermissions.1.FromPort=22&IpPermissions.1.ToPort=22&IpPermissions.1.IpRanges.1.CidrIP=0.0.0.0/0&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> test.log
    #resp="<CreateSubnetResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUPRULEOUT="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUPRULEOUT "Fail to create SecurityGroupRule - Egress"



    #resp=$(echo $(./create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=RevokeSecurityGroupIngress&GroupId=$SECURITYGROUP&IpPermissions.1.IpProtocol=tcp&IpPermissions.1.FromPort=22&IpPermissions.1.ToPort=22&IpPermissions.1.IpRanges.1.CidrIP=0.0.0.0/0&Version=2015-10-01") | source /dev/stdin)
    #echo $resp #>> test.log
    #resp="<CreateSubnetResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    #regex="(>true<)"
    #if [[ $resp =~ $regex ]]; then
    #    REVSECURITYGROUPRULEIN="${BASH_REMATCH[1]}"
    #fi
    #die_if_not_set $LINENO $REVSECURITYGROUPRULEIN "Fail to remove SecurityGroupRule - Ingress"


    #resp=$(echo $(./create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=RevokeSecurityGroupEgress&GroupId=$SECURITYGROUP&IpPermissions.1.IpProtocol=tcp&IpPermissions.1.FromPort=22&IpPermissions.1.ToPort=22&IpPermissions.1.IpRanges.1.CidrIP=0.0.0.0/0&Version=2015-10-01") | source /dev/stdin)
    #echo $resp #>> test.log
    #resp="<CreateSubnetResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    #regex="(>true<)"
    #if [[ $resp =~ $regex ]]; then
    #    REVSECURITYGROUPRULEOUT="${BASH_REMATCH[1]}"
    #fi
    #die_if_not_set $LINENO $REVSECURITYGROUPRULEOUT "Fail to create SecurityGroupRule - Egreass"


    echo "Successfully Created/Deleted Security Group Rules"    


}


describeSeucrityGroup() {

    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=DescribeSecurityGroups&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> test.log
    #resp="<CreateSubnetResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="($SECURITYGROUP)"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUPIDCheck="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUPIDCheck "Fail to describe Security Group"
    echo "Successfully Described SecurityGroup" 

}


deleteSecurityGroup() {

    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=DeleteSecurityGroup&GroupId=$SECURITYGROUP&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> test.log
    #resp="<CreateSubnetResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        SECURITYGROUPDELETE="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SECURITYGROUPDELETE "Fail to delete Security Group -- DO IT MANUALLY"
    echo "Successfully Deleted SecurityGroup" 

}

deleteSubnet() {


    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=DeleteSubnet&SubnetId=$SUBNETID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> test.log
    #resp="<CreateSubnetResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        SUBNETDELETE="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $SUBNETDELETE "Fail to delete Subnet -- DO IT MANUALLY"
    echo "Successfully Deleted Subnet" 

}


deleteVpc () {

    resp=$(echo $(create_request "https://vpc.ind-west-1.staging.jiocloudservices.com/services/Cloud/?Action=DeleteVpc&VpcId=$VPCID&Version=2015-10-01") | source /dev/stdin)
    echo $resp >> test.log
    #resp="<CreateSubnetResponse xmlns="http://vpc.ind-west-1.jiocloudservices.com/doc/2015-10-01/"> <requestId>req-db6e717b-49e3-4f49-81e7-d32d3bf9bb6a</requestId> <subnet> <mapPublicIpOnLaunch>false</mapPublicIpOnLaunch> <availableIpAddressCount>252</availableIpAddressCount> <defaultForAz>false</defaultForAz> <state>available</state> <vpcId>vpc-f46afdc0</vpcId> <subnetId>subnet-54001ea9</subnetId> <cidrBlock>192.168.1.0/24</cidrBlock> </subnet> </CreateSubnetResponse>"
    regex="(>true<)"
    if [[ $resp =~ $regex ]]; then
        VPCDELETE="${BASH_REMATCH[1]}"
    fi
    die_if_not_set $LINENO $VPCDELETE "Fail to delete VPC -- DO IT MANUALLY"
    echo "Successfully Deleted VPC" 


}

createVpc
describeVpc
createSubnet
describeSubnet
createSecurityGroup
createSecurityGroupRules
describeSeucrityGroup
deleteSecurityGroup
deleteSubnet
deleteVpc
echo "[PASS]"
