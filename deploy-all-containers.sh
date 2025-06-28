#!/bin/bash

docker run -d --name web01 debian:bullseye-slim sleep 3600
docker run -d --name web02 debian:bullseye-slim sleep 3600
docker run -d --name lb01 -p 8080:80 debian:bullseye-slim sleep 3600

# Run the Jenkins container
docker run -d --name jenkins \
  -p 8081:8080 \
  -p 50000:50000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/var/jenkins_home/workspace/ansible-lab-pipeline \
  custom-jenkins

docker ps