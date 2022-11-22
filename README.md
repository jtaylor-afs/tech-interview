# tech-interview

This project is IaC that stands up a VM (AWS ec2 instance supported initially), deploys VS Code server with a custom configuration that makes it ready for sharing with interview candidates, and deploys a SWAG (https://fleet.linuxserver.io/image?name=linuxserver/swag) to use LetsEncrypt and provide certificate management.

This tool is intended to enable interviewing or training for DevOps Engineers and Software Engineers. Out of the box, it provides a shared whiteboard capability (via a draw.io plugin), VS Code Live Share with shared terminal, a provisioned and preconfigured Kubernetes (k3s) cluster accessible via the shared terminal, and a series of predefined scenarios for candidates to attempt (https://github.com/jtaylor-afs/workspace) along with the language runtimes required.

A potential candidate can do anything from compiling and running applications to deploying and exposing applications in the Kubernetes environment.

## Deploying
tech-interview is a simple bash script that only requires the user to already have aws cli installed and configured for access to the target environment. The script deploys an ec2 instance, configures K3s for Kubernetes runtime, deploys VS Code web UI and TLS via local containers, and sets up Route53 with necessary Hosted Zone and DNS record.

### Prerequistes
| Requirement | Description |
|---|---|
| aws cli | the bash script relies on aws cli configured and working on the host handling the script |
| aws resources | currently, the script relies on default VPC/Sec Group/Subnet. They should be accessible (permitted inbound rules to at least 80/443 (80 is necessary for LetsEncrypt certificate chanllenge process) |
| domain name | a domain name is required for LetsEncrypt. There is an option to ignore route53 and domain-related tasks but not having trusted signed certs breaks the useful components of VS Code. The domain used must be registered in AWS Route53.

Help output:
```
jtaylor@ubuntu-server:~/work/git/tech-interview$ bash deploy.sh -h

Usage: $cli_name [command]
Flags:
  -d, --domain          Specify Domain - must be registered in AWS account
  -sd, --subdomain      Specifies a subdomain (optional: default random 4 digit)
  -p, --password        Password for VS Code access (optional: uses default)
  -ami, --ami           AMI must have docker pre-installed (optional: default ecs gpu hvm)
  -in, --instance-type  AWS instance type (optional: default t2.small)
  X-an, --aws-subnet     AWS subnet ID (optional: uses default)
  X-as, --aws-secgroup   AWS security group (optional: uses default)
  X-kp, --aws-keypair    AWS Keypair to use (optional: creates new kp)
  -r53, --route53       Binary (true/false) - enables/disables Route53 propagation
  -c, --clean           Destroys created resources
  -h, --help            Display Help+0
```

### Script options
| Flag | Description | Default |
|---|---|---|
| domain | the domain name to use for your instance. All instances get a configurable subdomain | wooden-proton.com |
| subdomain | specific subdomain for your particular instance. You can have many deployments with the same domain but different subdomains | random 4 numbers |
| password | password for VS Code UI access | Password!23 |
| ami | ami ID to use for your VS Code server instance. This AMI must be RHEL based and have docker installed | Amazon Linux 2 ECS-optimized  |
| instance type | AWS instance type. Should choose a larger instance if intending on running large Kubernetes workloads or intense applications but default works for general usage | t2.small |
| route53 | currently required to be true. If false, TLS will not get set up. Code server would still be reachable on a non-TLS port but most usability breaks with VS Code without TLS | true |
| clean | destroys all created AWS resources and locally created ones | - |

### Typical deployment:
```
jtaylor@ubuntu-server:~/work/git/tech-interview$ bash deploy.sh -d wooden-proton.com -p mypassword
Preparing configuration files
Deploying t2.small ec2 instance
  Waiting for instance 6084 to come online
  Public IP: 35.91.147.78

Adding Route53 Zone and Record
* please ensure your domain is registered with your AWS account *
  Hosted Zone already exists... skipping
  Creating A record for: 6084.wooden-proton.com : 35.91.147.78

###################################################
Initiating cloud-init script (may be a few minutes)

Default AWS cloud-init running
Installing yum packages on the host
Cloning git repositories
Starting VS Code and SWAG
 - Waiting on UI healthcheck
 - UI up and running and TLS configured
Installing dependencies for VS Code
Installing VS Code extensions
 - Live Share
 - Draw.io
 - Go
 - Python
 - Java Extension Pack
Installing Kubernetes (K3s)

***Installation complete ***

        To connect to your web session navigate to:
        https://6084.wooden-proton.com
        and login with your password: mypassword

        To connect to the SSH terminal:
        ssh -i deployment/6084-interview ec2-user@35.91.147.78

        When finished with your interview, please tear down your instance:
        ./deploy.sh -c

        A local log of the AWS resources is present in deployment/deployment.log
        The resources that were created are in deployment/interview_manifest.yaml
```

## Accessing

The deployment takes about 5 minutes and runs as a cloud-init script. 

Now you can navigate to the url in your browser and login with your password. If you did not set one, it will default to **Password!23**.

Once you are logged into code-server, click on the Live Server icon in the left pane and follow the prompts to begin sharing a session:
<insert image here>

Now you just need to share this link with the candidate and you will be on a live VS Code server with Kubernetes running and available. You can bring up a shared terminal and just start running **kubectl** commands.

## Interviewing
This tool currently provides interviewing capability for DevOps Engineer and Software Engineer

### DevOps Engineer

### Software Engineer

## Cleanup
Simply run the script again but with the `-c` flag and the deployer will clean up all cloud and local resources that were created:

```
jtaylor@ubuntu-server:~/work/git/tech-interview$ bash deploy.sh -c

#############################
# Cleaning cloud resources
#############################

Deleting keypair 6084.interview
Deleting EC2 instance i-0040f154ce3f12d6f
Deleting A record for in /hostedzone/Z04650833EMSRFIZAQDWN

#############################
# Cleaning local resources
#############################

DONE!
```