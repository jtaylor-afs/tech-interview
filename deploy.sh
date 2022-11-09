#!/bin/bash
###
# Default Variables
codeid=$((1000 + $RANDOM % 9999))
domain="code.wooden-proton.com"
password="Password!23" # password for code-server

# CLI Help
cli_help() {
  cli_name=${0##*/}

  echo "
Usage: $cli_name [command]
Flags:
  -d, --domain          Specify Domain
  -p, --password        Password for VS Code access (optional)
  -an, --aws-subnet     AWS subnet ID
  -as, --aws-secgroup   AWS security group
  -kp, --aws-keypair    AWS Keypair to use (optional)
  -c, --clean           Destroys created resources
  -h, --help            Display Help
"
}

# Clean AWS resources
clean() {
    # for IDs in manifest, aws delete stuff
    echo "X Y and Z were removed"
    exit 1
}

# Deploy the ec2 instance
deploy() {
    ami_id=$(aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amzn2-ami*' 'Name=state,Values=available' --output json | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId')
    instance_type="t3.large"

    # Create the keypair
    aws ec2 create-key-pair \
    --key-name  $codeid.interview \
    --query 'KeyMaterial' --output text > $codeid-interview

    # Deploy the ec2 instance to default VPC/subnet/secgroup
    aws ec2 run-instances \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=interview-$codeid}]" \
    --image-id $ami_id \
    --instance-type $instance_type \
    --key-name $codeid.interview \
    --user-data file://user_data.sh
    ## Add in below as options later
    #--subnet-id <subnet-id> \
    #--security-group-ids <security-group-id> <security-group-id>
    echo "
    ############################
    # VM is standing up
    # Can take up to 5 minutes
    ############################
    "

    # Store AWS resources to manifest for clean function
    echo "keypair: $codeid.interview" > interview_manifest.yaml
    echo "ec2: interview-$codeid" >> interview_manifest.yaml
}

# CLI Flags
flags()
{
    case "$1" in
    -d|--domain)
        export domain=$2
        ;;
    -p|--password)
        export password=$2
        ;;
    -as|--aws-secgroup)
        export subnet=$2
        ;;
    -an|--aws-subnet)
        export subnet=$2
        ;;
    -kp|--aws-keypair)
        export keypair=$2
        ;;
    -c|--clean)
        clean
        ;;
    -h|--help)
        export help_prompt=true
        ;;
    esac

    deploy
}
flags "$@"
