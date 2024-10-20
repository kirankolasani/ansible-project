#!/bin/bash

NAMES=$@
INSTANCE_TYPE=""
IMAGE_ID=ami-0b4f379183e5706b9
SECURITY_GROUP_ID=sg-0fa491629b46961b3
DOMAIN_NAME=myclouddevops.site
HOSTED_ZONE_ID=Z05655982YUUIGPUK2DX1

for i in $NAMES
do
    # Set instance type based on the application
    if [[ $i == "mongodb" || $i == "mysql" ]]; then
        INSTANCE_TYPE="t3.medium"
    else
        INSTANCE_TYPE="t2.micro"
    fi

    # Check if the instance already exists
    INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$i" --query "Reservations[*].Instances[*].InstanceId" --output text)
    
    if [ -n "$INSTANCE_ID" ]; then
        echo "$i instance already exists: $INSTANCE_ID"
        IP_ADDRESS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[*].Instances[*].PrivateIpAddress" --output text)
    else
        echo "Creating $i instance"
        IP_ADDRESS=$(aws ec2 run-instances --image-id $IMAGE_ID --instance-type $INSTANCE_TYPE --security-group-ids $SECURITY_GROUP_ID --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$i}]" | jq -r '.Instances[0].PrivateIpAddress')
        echo "Created $i instance: $IP_ADDRESS"
    fi

    # Check if the Route 53 record already exists
    RECORD_EXISTS=$(aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --query "ResourceRecordSets[?Name == '$i.$DOMAIN_NAME.']" --output text)
    
    if [ -n "$RECORD_EXISTS" ]; then
        echo "Updating Route 53 record for $i.$DOMAIN_NAME"
        ACTION="UPSERT"
    else
        echo "Creating Route 53 record for $i.$DOMAIN_NAME"
        ACTION="CREATE"
    fi

    aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
        "Changes": [{
            "Action": "'$ACTION'",
            "ResourceRecordSet": {
                "Name": "'$i.$DOMAIN_NAME'",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [{ "Value": "'$IP_ADDRESS'" }]
            }
        }]
    }'
done
