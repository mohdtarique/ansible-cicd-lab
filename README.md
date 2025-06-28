# Full CI/CD Pipeline for Ansible with Jenkins & Docker

This repository contains a complete, local CI/CD pipeline that demonstrates professional DevOps practices. It uses Jenkins to automate the deployment of a web server environment (a load balancer and two web servers) provisioned with Ansible inside Docker containers.

The pipeline is designed to be robust, incorporating automated quality gates such as code linting and security scanning before any deployment occurs.

## Key Features

* **Automation with Ansible:** Infrastructure configuration is managed entirely through Ansible roles and playbooks.
* **Containerized Environment:** Docker is used to create a clean, isolated, and repeatable environment for all components.
* **CI/CD Orchestration with Jenkins:** Jenkins automates the entire workflow, from cloning the code to testing and deployment.
* **Pipeline as Code:** The entire CI/CD process is defined in a `Jenkinsfile`, making it version-controlled and transparent.
* **Automated Quality & Security Gates:**
    * **Linting:** `ansible-lint` automatically checks the codebase for best practices and potential errors.
    * **Security Scanning:** `Trivy` scans Infrastructure as Code (IaC) files for security misconfigurations.
* **Custom Jenkins Environment:** A custom Docker image is built for Jenkins, containing all the necessary tools (`Ansible`, `Docker`, `Trivy`, `jq`) for the pipeline.

---

## Core Technology Stack

This project brings together several key DevOps tools and practices. Here is a detailed explanation of each component.

### Docker

* **Official Definition:** Docker is an open platform for developing, shipping, and running applications. Docker enables you to separate your applications from your infrastructure so you can deliver software quickly. With Docker, you can manage your infrastructure in the same ways you manage your applications.
* **Implementation in This Project:** We use Docker to create four separate container instances on a single local machine: one for the Jenkins controller, one for the Nginx load balancer, and two for the Nginx web servers. This allows us to simulate and test a realistic, multi-server architecture without requiring physical hardware.
* **Industry Use Cases:** Docker is the industry standard for containerization. It is used extensively for building microservices-based applications, creating consistent development and testing environments, and deploying applications at scale in the cloud. It ensures that an application works uniformly, regardless of where it is run.

### Ansible

* **Official Definition:** Ansible is an open-source automation tool that automates software provisioning, configuration management, and application deployment. It is agentless, temporarily connecting remotely via SSH or other standard protocols to do its tasks.
* **Implementation in This Project:** Our Ansible playbooks automate the entire configuration of our server containers. The primary playbook (`site.yml`) first installs Python, then applies a `common` role for baseline setup, and finally applies an `nginx` role to install and configure the web servers and load balancer based on their group membership in the inventory.
* **Industry Use Cases:** Ansible is a cornerstone of modern IT automation and is used for a wide range of tasks, including:
    * **Configuration Management:** Enforcing a desired state across thousands of servers to ensure consistency.
    * **Application Deployment:** Deploying and updating applications across complex environments.
    * **Provisioning:** While tools like Terraform are often preferred for creating infrastructure, Ansible can also provision cloud instances, storage, and networking.
    * **Security & Compliance:** Applying security patches and running compliance checks across an entire fleet of servers.

### Jenkins

* **Official Definition:** Jenkins is a self-contained, open-source automation server which can be used to automate all sorts of tasks related to building, testing, and delivering or deploying software.
* **Implementation in This Project:** Jenkins serves as the central orchestrator for our CI/CD pipeline. It is configured to monitor the GitHub repository, and upon a new commit, it automatically clones the code, runs a series of quality and security checks, and, if they pass, executes the Ansible playbook to deploy the infrastructure.
* **Industry Use Cases:** Jenkins is one of the most popular CI/CD tools in the world. It acts as the backbone of the software delivery process, integrating with a vast ecosystem of tools to automate everything from compiling code and running unit tests to deploying complex applications to production environments like Kubernetes.

### Pipeline as Code & the `Jenkinsfile`

* **Official Definition:** Pipeline as Code is the practice of defining the deployment pipeline through code instead of configuring it in a UI. A `Jenkinsfile` is a text file that contains the definition of a Jenkins Pipeline and is checked into source control.
* **Implementation in This Project:** Our `Jenkinsfile` defines the entire CI/CD workflow in a series of stages (`Initialize`, `Lint`, `Scan`, `Deploy`, `Verify`). By storing this definition as code in our Git repository, the pipeline itself becomes version-controlled, reviewable, and easy to modify.
* **Industry Use Cases:** This is a fundamental DevOps principle. It ensures the CI/CD process is transparent, reproducible, and not dependent on a single person's "magic clicks" in a UI. It allows teams to collaborate on the deployment process just as they do with application code.

### Automated Quality & Security Gates (`ansible-lint` and `Trivy`)

* **Official Definition:** These are automated checks integrated into a CI/CD pipeline to enforce quality and security standards. `ansible-lint` checks Ansible code for best practices, and `Trivy` is a comprehensive security scanner.
* **Implementation in This Project:** We have dedicated stages in our `Jenkinsfile` that run these tools. The `ansible-lint` stage checks our playbooks for stylistic errors and potential bugs. The `Trivy` stage scans our `Dockerfile` and other configuration files for known security vulnerabilities and misconfigurations. The pipeline is configured to fail if these checks do not meet a specified quality bar, preventing flawed code from being deployed.
* **Industry Use Cases:** This practice is known as **DevSecOps** or **"shifting left"** on security. By integrating automated security and quality checks directly into the development workflow, organizations can identify and remediate issues early, dramatically reducing the risk and cost associated with fixing them later in the production environment.

---

## Project Architecture & File Definitions

This project uses a standard, best-practice directory structure for Ansible. Each file has a specific purpose.

```
.
├── ansible.cfg
├── Dockerfile.jenkins
├── group_vars
│   └── webservers.yml
├── inventory.ini
├── Jenkinsfile
├── README.md
├── roles
│   ├── common
│   │   └── tasks
│   │       └── main.yml
│   └── nginx
│       ├── defaults
│       │   └── main.yml
│       ├── handlers
│       │   └── main.yml
│       ├── tasks
│       │   └── main.yml
│       └── templates
│           ├── index.html.j2
│           └── loadbalancer.conf.j2
└── site.yml
```

### `ansible.cfg`
* **Purpose:** The main configuration file for Ansible. It tells Ansible how to behave within this project.

```ini
# The [defaults] section contains core Ansible settings.
[defaults]

# Points to our inventory file where we define our servers.
inventory = inventory.ini

# Disables SSH host key checking, which is necessary for temporary Docker containers.
host_key_checking = False

# Sets the default user for connecting to our target containers.
remote_user = root

# Tells Ansible where to create temporary files on the target machines.
# Using /tmp is more reliable in minimal container environments.
remote_tmp = /tmp/ansible-tmp

# The [privilege_escalation] section defines how Ansible gains admin rights.
[privilege_escalation]

# 'become = True' is equivalent to using 'sudo' before commands.
become = True
```

### `inventory.ini`
* **Purpose:** Defines the servers (hosts) that Ansible will manage, organized into groups.

```ini
# Defines a group for our load balancer.
[loadbalancer]
# 'lb01' is the alias. 'ansible_host=lb01' tells Ansible to connect to a host named 'lb01'.
lb01 ansible_host=lb01

# Defines a group for our web servers.
[webservers]
web01 ansible_host=web01
web02 ansible_host=web02

# The [all:vars] section sets variables that apply to every host in this inventory.
[all:vars]
# Tells Ansible to use the 'docker' connection plugin instead of default SSH.
ansible_connection=docker
# Specifies the exact path to the Python interpreter on the target containers.
ansible_python_interpreter=/usr/bin/python3
```

### `site.yml`
* **Purpose:** The "master" or "main" playbook that orchestrates the entire deployment.

```yaml
---
# This is the first play, a bootstrap step to prepare all hosts.
- name: Prepare all hosts for Ansible
  # 'hosts: all' targets every server in our inventory.
  hosts: all
  # 'gather_facts: false' skips gathering system information, as it's not needed here.
  gather_facts: false
  # 'pre_tasks' are tasks that run before any roles are applied.
  pre_tasks:
    # This task installs Python, which is required by Ansible to run most modules.
    - name: Update apt cache and install python3
      # The 'raw' module sends a raw shell command, necessary when Python isn't yet installed.
      raw: apt-get update && apt-get install -y python3

# The second play applies common configuration to all hosts.
- name: Apply common configuration to all hosts
  hosts: all
  roles:
    # Applies the 'common' role.
    - common

# This play configures only the web servers.
- name: Configure web servers
  hosts: webservers
  roles:
    # Applies the 'nginx' role.
    - nginx

# This play configures only the load balancer.
- name: Configure load balancer
  hosts: loadbalancer
  roles:
    - nginx
```

### `Dockerfile.jenkins`
* **Purpose:** A recipe for building our custom Jenkins Docker image, which includes all the tools our pipeline needs.

```dockerfile
# Start from an official Jenkins Long-Term Support (LTS) image.
FROM jenkins/jenkins:lts-jdk11

# Define a build-time argument to accept the Docker Group ID from the host.
ARG DOCKER_GID

# Switch to the root user to install system software.
USER root

# Install prerequisites for adding custom software repositories.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    apt-transport-https \
    ca-certificates

# Add the official repositories for Ansible and Trivy.
RUN echo "deb [http://ppa.launchpad.net/ansible/ansible/ubuntu](http://ppa.launchpad.net/ansible/ansible/ubuntu) focal main" | tee /etc/apt/sources.list.d/ansible.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367 && \
    wget -qO - [https://aquasecurity.github.io/trivy-repo/deb/public.key](https://aquasecurity.github.io/trivy-repo/deb/public.key) | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] [https://aquasecurity.github.io/trivy-repo/deb](https://aquasecurity.github.io/trivy-repo/deb) $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list

# Install all the main applications in a single layer to optimize image size.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    ansible \
    ansible-lint \
    trivy \
    jq && \
    # Clean up apt cache to keep the image small.
    rm -rf /var/lib/apt/lists/*

# Install the Docker command-line client.
RUN curl -fsSL [https://download.docker.com/linux/debian/gpg](https://download.docker.com/linux/debian/gpg) | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] [https://download.docker.com/linux/debian](https://download.docker.com/linux/debian) $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Create a 'docker' group with the specific GID passed from the host system.
# Then add the 'jenkins' user to this group to grant it permission to use the Docker socket.
RUN groupadd -g ${DOCKER_GID:-999} docker && usermod -aG docker jenkins

# Switch back to the non-privileged 'jenkins' user for security.
USER jenkins

# Add a healthcheck to allow Docker to monitor the container's status.
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/login || exit 1
```

### `Jenkinsfile`
* **Purpose:** Defines our CI/CD pipeline as code, dictating the stages and steps Jenkins will execute.

```groovy
// Defines the start of a declarative pipeline.
pipeline {
    // 'agent any' means this pipeline can run on any available Jenkins agent.
    agent any
    // The 'stages' block contains the sequence of steps for our pipeline.
    stages {
        // First stage: Initialize and print version info for debugging.
        stage('Initialize') {
            steps {
                sh 'echo "Starting Ansible deployment..."'
                sh 'ansible --version'
                sh 'docker --version'
            }
        }
        // Second stage: Perform static code analysis on our Ansible code.
        stage('Lint and Syntax Check') {
            steps {
                sh 'echo "Running Ansible Lint..."'
                // Runs the linter to check for best practices and errors.
                sh 'ansible-lint .'

                sh 'echo "Running Ansible Syntax Check..."'
                // Performs a dry-run to validate the playbook syntax without making changes.
                sh 'ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventory.ini --syntax-check site.yml'
            }
        }
        // Third stage: Scan our Infrastructure as Code for security issues.
        stage('Security Scan') {
            steps {
                // A multi-line shell script to implement custom failure logic.
                sh '''
                    echo "Running Trivy IaC Scan for CRITICAL issues..."
                    # Run Trivy to find only CRITICAL issues and output to a JSON file.
                    # --exit-code 0 prevents this command from failing the build; we'll fail it manually.
                    trivy config --exit-code 0 --severity CRITICAL --format json . > trivy_critical_report.json

                    echo "Analyzing Trivy report..."
                    # Use 'jq' (a JSON processor) to count the number of files with critical issues.
                    CRITICAL_FILES_COUNT=$(jq 'if .Results then .Results | length else 0 end' trivy_critical_report.json)
                    echo "Found $CRITICAL_FILES_COUNT file(s) with critical issues."

                    # Check if the count exceeds our threshold of 2.
                    if [ "$CRITICAL_FILES_COUNT" -gt 2 ]; then
                        echo "FAILURE: Found $CRITICAL_FILES_COUNT files with critical issues, which is more than the allowed threshold of 2."
                        # Explicitly fail the Jenkins pipeline with a clear error message.
                        error "Pipeline failed due to critical security findings in more than 2 files."
                    else
                        echo "SUCCESS: The number of files with critical issues is within the threshold."
                    fi
                '''
            }
        }
        // Fourth stage: Deploy the application if all previous checks pass.
        stage('Run Ansible Playbook') {
            steps {
                // Run the main playbook. ANSIBLE_CONFIG forces it to use our local config file.
                sh 'ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventory.ini site.yml'
            }
        }
        // Final stage: Verify that the deployment was successful.
        stage('Verify Deployment') {
            steps {
                sh 'echo "Deployment finished. Checking load balancer status..."'
                // Use curl to test the load balancer. The --fail flag causes curl to exit with an error
                // if the HTTP response code is not 2xx, which would fail the pipeline.
                sh 'curl --fail http://lb01/'
                sh 'curl --fail http://lb01/'
            }
        }
    }
    // The 'post' block defines actions that run at the end of the pipeline.
    post {
        // 'always' ensures this step runs regardless of whether the pipeline succeeded or failed.
        always {
            echo 'Pipeline finished.'
        }
    }
}
```

### Roles and Other Files
* **`group_vars/webservers.yml`:** Defines variables that apply only to the `webservers` group.
* **`roles/`:** A directory containing reusable units of Ansible automation.
    * **`common/`:** A role with tasks that apply to all servers, like installing common packages.
    * **`nginx/`:** A role for installing and configuring Nginx. It's smart enough to act as a web server or a load balancer based on the host it's running on.
        * **`tasks/`:** The main logic and steps for the role.
        * **`templates/`:** Contains template files (`.j2`) used to generate dynamic configuration files.
        * **`handlers/`:** Contains tasks that are only triggered by other tasks (e.g., restarting a service only when its config changes).
        * **`defaults/`:** Contains default variables for the role.

---

## How to Run This Project

Follow these steps in a Linux-based terminal (like WSL on Windows).

### Prerequisites

* **Docker** must be installed.
* Your user must have permission to run `docker` commands.

### Step 1: Clean Up and Create the Environment

This command ensures a clean start by removing any old containers and the project network.

```bash
# Stop and remove any old containers and the network
docker stop web01 web02 lb01 jenkins && docker rm web01 web02 lb01 jenkins
docker network rm ansible-network

# Create the dedicated network for our containers
docker network create ansible-network
```

### Step 2: Build the Custom Jenkins Image

This command builds our custom Jenkins image from the `Dockerfile.jenkins`. The `--build-arg` dynamically passes your system's Docker Group ID (GID) into the build process, which is critical for solving Docker-in-Docker permission issues.

```bash
docker build --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3) -t custom-jenkins -f Dockerfile.jenkins .
```

### Step 3: Run All Docker Containers

This starts the three "server" containers and the main Jenkins controller, all connected to the same custom network.

```bash
# Start the target "server" containers
docker run -d --name web01 --network ansible-network debian:bullseye-slim sleep 3600
docker run -d --name web02 --network ansible-network debian:bullseye-slim sleep 3600
docker run -d --name lb01 --network ansible-network -p 8080:80 debian:bullseye-slim sleep 3600

# Run the Jenkins controller container
docker run -d --name jenkins --network ansible-network \
  -p 8081:8080 \
  -p 50000:50000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  custom-jenkins
```

### Step 4: Configure the Jenkins Pipeline

* **Get Admin Password:** Run `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
* **Log In:** Open a browser to **`http://localhost:8081`** and use the password.
* **Setup:** Click "Install suggested plugins" and create your own permanent admin user account.
* **Create the Pipeline Job:**
    1.  Click **New Item** on the Jenkins dashboard.
    2.  Enter a name (e.g., `ansible-cicd-from-github`).
    3.  Select **Pipeline** and click **OK**.
    4.  Scroll down to the **Pipeline** section.
    5.  Change the **Definition** dropdown to **Pipeline script from SCM**.
    6.  **SCM:** Select **Git**.
    7.  **Repository URL:** Enter the HTTPS URL of your GitHub repository.
    8.  **Branch Specifier:** Ensure it is set to `*/main`.
    9.  **Script Path:** Ensure it is `Jenkinsfile`.
    10. Click **Save**.

### Step 5: Run the Pipeline and Verify

* On the job's page, click **"Build Now"**.
* Watch the pipeline execute through all its stages in the "Stage View".
* After it succeeds, open a new terminal and run `curl http://localhost:8080` a few times. You should see the HTML response alternate between `web01` and `web02`.

---

## Final Result Screenshot

After the pipeline completes successfully, the load balancer is accessible at `http://localhost:8080` from your local machine. It will route traffic to the two web servers (`web01` and `web02`). Refreshing the page will alternate the "You have connected to host" message between the two servers.

<img width="961" alt="image" src="https://github.com/user-attachments/assets/5576c48a-dce7-49ea-bf98-f0d3b89d1eff" />
