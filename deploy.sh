#!/bin/bash
###
# Default Variables
codeid=$((1000 + RANDOM % 8999))
domain="wooden-proton.com"
password="Password!23" # password for code-server
route=true

# CLI Help
cli_help() {
  cli_name=${0##*/}

  echo "
Usage: $cli_name [command]
Flags:
  -d, --domain          Specify Domain - must be registered in AWS account
  -sd, --subdomain      Specifies a subdomain (optional: default random 4 digit)
  -p, --password        Password for VS Code access (optional: uses default)
  X-an, --aws-subnet     AWS subnet ID (optional: uses default)
  X-as, --aws-secgroup   AWS security group (optional: uses default)
  X-kp, --aws-keypair    AWS Keypair to use (optional: creates new kp)
  -r53, --route53       Binary (true/false) - enables/disables Route53 propagation
  -c, --clean           Destroys created resources
  -h, --help            Display Help
"
exit 1
}

# Clean AWS resources
clean() {
    # for IDs in manifest, aws delete stuff
    printf "
#############################
# Cleaning cloud resources
#############################\n\n"
    cat deployment/interview_manifest.yaml | while read line || [[ -n $line ]];
    do
        i=$(echo "$line" | awk '{print $1}')
        j=$(echo "$line" | awk '{print $2}')
        # Case statement for the only possibilities
        case $i in
        keypair:)
            echo "Deleting keypair $j"
            aws ec2 delete-key-pair --key-name "$j" >> deployment/deployment.log
            ;;
        ec2:)
            echo "Deleting EC2 instance $j"
            aws ec2 terminate-instances --instance-ids "$j" >> deployment/deployment.log
            ;;
        hzid:)
            echo "Deleting Hosted Zone $j"
            aws route53 delete-hosted-zone --id "$j" >> deployment/deployment.log
            ;;
        record:)
            hzid=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${domain}.'].Id" --output text)
            echo "Deleting A record for in $hzid"
            sed -i "s/CREATE/DELETE/g" deployment/dns_record.json
            aws route53 change-resource-record-sets --hosted-zone-id "$hzid" --change-batch file://deployment/dns_record.json >> deployment/deployment.log
            ;;
        esac
    done
    printf "
#############################
# Cleaning local resources
#############################\n\n"
    rm -rf deployment/
    printf "DONE!\n\n"
    exit 1
}

# Prepare ec2 user data files
# These files are used by the user data script which cannot be passed with
# args so manual preparation here must take place
prepare() {
    printf "Preparing configuration files\n"

    # Make ephemeral config file location
    mkdir deployment
    cp user_data.sh config/dns_record.json deployment/

    # Apply changes that can me applied early
    # This has to happen due to these files being used by cloud-init
    # and passed via the aws cli command so unable to pass variables
    sed -i "s/1234/$codeid/g" deployment/user_data.sh
    sed -i "s/Password123/$password/g" deployment/user_data.sh
    sed -i "s/wooden-proton.com/$domain/g" deployment/user_data.sh
    sed -i "s/subdomain/$codeid/g" deployment/dns_record.json
    sed -i "s/domain/$domain/g" deployment/dns_record.json
}

# Create the Route53 record
route() {
    echo "
    Adding Route53 Zone and Record
    * please ensure your domain is registered with your AWS account *"
    
    # Creating new Hosted Zone only if it does not already exist
    routeexist=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${domain}.'].Name" --output text)
    if [ "$domain." = "$routeexist" ]; then
        printf "Hosted Zone already exists... skipping\n"
    else
        echo "Creating Hosted Zone"
        aws route53 create-hosted-zone --name $domain --caller-reference $codeid >> deployment/deployment.log
        hzid=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${domain}.'].Id" --output text)
        echo "route53: $hzid" >> deployment/interview_manifest.yaml
    fi

    # Creating new A record for domain
    printf 'Creating A record for: %s\n\n' "$codeid.$domain : $1"
    hzid=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${domain}.'].Id" --output text)
    sed -i "s/192.168.1.1/$1/g" deployment/dns_record.json
    aws route53 change-resource-record-sets --hosted-zone-id "$hzid" --change-batch file://deployment/dns_record.json >> deployment/deployment.log
    echo "record: true" >> deployment/interview_manifest.yaml

}


# Deploy the ec2 instance
deploy() {
    ami_id=$(aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amzn2-ami*' 'Name=state,Values=available' --output json | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId')
    instance_type="t3.small"

    # Create the keypair
    aws ec2 create-key-pair \
    --key-name  $codeid.interview \
    --query 'KeyMaterial' --output text > deployment/$codeid-interview
    chmod 600 deployment/$codeid-interview

    # Deploy the ec2 instance to default VPC/subnet/secgroup
    aws ec2 run-instances \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=interview-$codeid}]" \
    --image-id "$ami_id" \
    --instance-type $instance_type \
    --key-name $codeid.interview \
    --user-data file://deployment/user_data.sh >> deployment/deployment.log
    ## Add in below as options later
    #--subnet-id <subnet-id> \
    #--security-group-ids <security-group-id> <security-group-id>
    
    sleep 5

    public_ip=$(aws ec2 describe-instances --filters Name=tag-value,Values=interview-$codeid Name=instance-state-name,Values=running --query "Reservations[*].Instances[*].PublicIpAddress" --output text)
    
    # Store AWS resources to manifest for clean function
    instance_id=$(aws ec2 describe-instances --filters Name=tag-value,Values=interview-$codeid Name=instance-state-name,Values=running --query "Reservations[*].Instances[*].InstanceId" --output text)
    echo "keypair: $codeid.interview" > deployment/interview_manifest.yaml
    echo "ec2: $instance_id" >> deployment/interview_manifest.yaml
    
    # Create Route53 DNS zone and record
    if [ $route = true ]; then
        route "$public_ip"
    else
        echo "record: false" >> deployment/interview_manifest.yaml
    fi

    echo "
    ############################
    # VM is standing up
    # Can take up to 5 minutes
    ############################

    To connect to your web session navigate to:
    https://$codeid.$domain
    and login with your password: $password

    To connect to the SSH terminal:
    ssh -i deployment/$codeid-interview ec2-user@$public_ip
    To follow along with the deployment:
    ssh -i deployment/$codeid-interview ec2-user@$public_ip "sudo tail -f /var/log/cloud-init-output.log"
    
    When finished with your interview, please tear down your instance:
    ./deploy.sh -c

    A local log of the AWS resources is present in deployment/deployment.log
    The resources that were created are in deployment/interview_manifest.yaml
    "
    ssh -i deployment/$codeid-interview -o StrictHostKeyChecking=no -o LogLevel=error ec2-user@"$public_ip" "sudo touch /var/log/passage.log"
    ssh -i deployment/$codeid-interview -o StrictHostKeyChecking=no ec2-user@"$public_ip" "sudo tail -10f /var/log/passage.log"
}

# CLI Flags
flags()
{
    case "$1" in
    -d|--domain)
        export domain=$2
        ;;
    -sd|--subdomain)
        export codeid=$2
        ;;
    -p|--password)
        export password=$2
        ;;
    -as|--aws-secgroup)
        export secgroup=$2
        ;;
    -an|--aws-subnet)
        export subnet=$2
        ;;
    -kp|--aws-keypair)
        export keypair=$2
        ;;
    -r53|--route53)
        export route=$2
        ;;
    -c|--clean)
        clean
        ;;
    -h|--help)
        cli_help
        ;;
    -*)
        cli_help
        ;;
    esac

    prepare
    deploy
}
flags "$@"
