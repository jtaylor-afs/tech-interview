#!/bin/bash

yum update -y
yum install -y git 

git clone https://github.com/eficode-academy/kubernetes-katas.git /home/ec2-user
git clone https://github.com/jtaylor-afs/tech-interview.git /home/ec2-user
