# Automated Web Server Deployment with Ansible, Docker, and Jenkins

This project demonstrates a complete, local CI/CD (Continuous Integration/Continuous Deployment) pipeline. It uses Ansible to automatically provision a web server environment (a load balancer and two web servers) running in Docker containers, with the entire process orchestrated by Jenkins.

This setup is a powerful, local replica of modern DevOps workflows, allowing you to learn and experiment with professional-grade automation without the need for cloud infrastructure.

## Core Concepts Explained

* **Docker:** A platform used to create, deploy, and run applications in lightweight, isolated environments called containers. In this project, we use Docker to simulate multiple "servers" (`web01`, `web02`, `lb01`, `jenkins`) on our local machine.
* **Ansible:** An open-source automation tool that automates software provisioning, configuration management, and application deployment. We use Ansible to install and configure Nginx on our Docker containers. It is *agentless*, meaning it connects to the target machines (our containers) over a standard connection without needing special software installed on them beforehand (besides Python).
* **Jenkins:** An open-source automation server that acts as our CI/CD orchestrator. Jenkins will automatically clone our project from GitHub and run the Ansible playbook to execute the deployment.
* **Pipeline as Code:** The practice of defining our deployment pipeline in a text file (`Jenkinsfile`) that is version-controlled along with our application code. This makes our CI/CD process transparent, repeatable, and easy to modify.

---

## Project Goal

The goal is to create a fully automated pipeline that does the following:

1.  **Jenkins clones** the project code from a GitHub repository.
2.  The pipeline **starts several Docker containers** on a dedicated network to simulate our infrastructure.
3.  **Ansible runs** to provision these containers:
    * It installs `python3` on all containers, a prerequisite for Ansible.
    * It installs and configures Nginx on two `webserver` containers.
    * It installs and configures Nginx as a load balancer on the `loadbalancer` container.
4.  The pipeline **verifies** that the deployment was successful.

---

## Project Structure and File Definitions

This project uses a standard, best-practice directory structure for Ansible projects.

```
ansible_local_project/
├── .github/
│   └── workflows/
│       └── ...
├── ansible.cfg
├── inventory.ini
├── site.yml
├── Dockerfile.jenkins
├── Jenkinsfile
├── group_vars/
│   └── webservers.yml
└── roles/
    ├── common/
    │   └── tasks/
    │       └── main.yml
    └── nginx/
        ├── tasks/
        │   └── main.yml
        ├── templates/
        │   ├── index.html.j2
        │   └── loadbalancer.conf.j2
        ├── handlers/
        │   └── main.yml
        └── defaults/
            └── main.yml
```

### File-by-File Explanation

#### `ansible.cfg`

* **Purpose:** This is the main configuration file for Ansible. It tells Ansible how to behave within this specific project directory.
* **Why it's used:** We use it to define our inventory file location, disable SSH host key checking (since we're using new Docker containers every time), and specify the default remote user (`root`) and temporary directory (`/tmp/ansible-tmp`) for our target containers.

```ini
[defaults]
inventory = inventory.ini
host_key_checking = False
remote_user = root
remote_tmp = /tmp/ansible-tmp

[privilege_escalation]
become = True
```

---

#### `inventory.ini`

* **Purpose:** This is Ansible's inventory file. It defines the "servers" or hosts that Ansible will manage.
* **Why it's used:** We group our hosts into `[webservers]` and `[loadbalancer]` to apply different configurations to them. The `[all:vars]` section sets variables that apply to every host, such as telling Ansible to use the `docker` connection plugin instead of the default SSH.

```ini
[loadbalancer]
lb01 ansible_host=lb01

[webservers]
web01 ansible_host=web01
web02 ansible_host=web02

[all:vars]
ansible_connection=docker
ansible_python_interpreter=/usr/bin/python3
```

---

#### `site.yml`

* **Purpose:** This is the "master" or "main" playbook. It orchestrates the entire deployment by defining which hosts will have which roles applied to them.
* **Why it's used:** It provides a high-level view of our automation. It first runs a `pre_tasks` block to install Python on all hosts (a bootstrap step). Then, it applies the `common` role to all hosts, and finally, applies the `nginx` role to the appropriate groups.

```yaml
---
- name: Prepare all hosts for Ansible
  hosts: all
  gather_facts: false
  pre_tasks:
    - name: Update apt cache and install python3
      raw: apt-get update && apt-get install -y python3

- name: Apply common configuration to all hosts
  hosts: all
  roles:
    - common

- name: Configure web servers
  hosts: webservers
  roles:
    - nginx

- name: Configure load balancer
  hosts: loadbalancer
  roles:
    - nginx
```

---

#### `Dockerfile.jenkins`

* **Purpose:** This is a "recipe" for building a custom Docker image.
* **Why it's used:** The standard Jenkins image does not include Ansible or Docker tools. We need a custom image for our Jenkins controller that has `git`, `ansible`, and the `docker` client installed so it can perform all the steps in our pipeline. It's also configured to handle Docker socket permissions correctly.

```dockerfile
# Use a trusted Jenkins LTS image as our base
FROM jenkins/jenkins:lts-jdk11

# Define an argument to accept the Docker GID from the host
ARG DOCKER_GID

# Switch to the root user to install software
USER root

# Install common dependencies, including git
RUN apt-get update && apt-get install -y git curl gnupg lsb-release software-properties-common

# Add Ansible PPA correctly and install Ansible
RUN echo "deb [http://ppa.launchpad.net/ansible/ansible/ubuntu](http://ppa.launchpad.net/ansible/ansible/ubuntu) focal main" | tee /etc/apt/sources.list.d/ansible.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
RUN apt-get update
RUN apt-get install -y ansible

# Install Docker CLI
RUN curl -fsSL [https://download.docker.com/linux/debian/gpg](https://download.docker.com/linux/debian/gpg) | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] [https://download.docker.com/linux/debian](https://download.docker.com/linux/debian) $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update
RUN apt-get install -y docker-ce-cli

# Create a docker group with the GID passed from the host, then add the jenkins user to it.
# This ensures the jenkins user has the correct permissions on the docker.sock file.
RUN groupadd -g ${DOCKER_GID:-999} docker && usermod -aG docker jenkins

# Switch back to the non-privileged jenkins user
USER jenkins
```

---

#### `Jenkinsfile`

* **Purpose:** Defines our entire CI/CD pipeline as code.
* **Why it's used:** Jenkins reads this file from our GitHub repository to know what steps to execute. It defines distinct stages for initialization, running the playbook, and verification. This makes our process version-controlled and easy to understand.

```groovy
// Jenkinsfile (Declarative Pipeline)
pipeline {
    agent any
    stages {
        // The 'Checkout' stage is now handled automatically by Jenkins
        // when using "Pipeline script from SCM"

        stage('Initialize') {
            steps {
                sh 'echo "Starting Ansible deployment..."'
                sh 'ansible --version'
                sh 'docker --version'
            }
        }
        stage('Run Ansible Playbook') {
            steps {
                // Set ANSIBLE_CONFIG to force ansible to read our config file
                sh 'ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventory.ini site.yml'
            }
        }
        stage('Verify Deployment') {
            steps {
                sh 'echo "Deployment finished. Checking load balancer status..."'
                sh 'curl --fail http://lb01/'
                sh 'curl --fail http://lb01/'
            }
        }
    }
    post {
        always {
            echo 'Pipeline finished.'
        }
    }
}
```

---

#### `group_vars/webservers.yml`

* **Purpose:** This file defines variables that apply *only* to the hosts in the `[webservers]` group.
* **Why it's used:** It's the perfect place to put data specific to our web servers, such as a custom greeting message. This separates configuration data from our automation logic.

```yaml
---
server_greeting: "This is a web server managed by Ansible!"
```

---

#### `roles/`

* **Purpose:** The `roles` directory is the primary way to organize and reuse Ansible content. Each subdirectory (`common`, `nginx`) is a self-contained role with its own tasks, templates, and handlers.

##### `roles/common/tasks/main.yml`

* **Purpose:** The main task file for the `common` role.
* **Why it's used:** Contains tasks that should be applied to *all* servers, such as ensuring essential packages like `curl` are installed.

```yaml
---
- name: Update APT package cache
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 3600

- name: Ensure essential packages are installed
  ansible.builtin.apt:
    name:
      - curl
      - vim
    state: present
```

##### `roles/nginx/tasks/main.yml`

* **Purpose:** The main task file for the `nginx` role.
* **Why it's used:** This file contains all the steps for setting up Nginx. It uses conditional logic (`when:`) to perform different actions depending on whether it's running on a load balancer or a web server. It also `notifies` a handler to restart Nginx only when a configuration file changes.

```yaml
---
- name: Install Nginx
  ansible.builtin.apt:
    name: nginx
    state: present

- name: Template the load balancer config
  ansible.builtin.template:
    src: loadbalancer.conf.j2
    dest: /etc/nginx/sites-available/default
  when: "'loadbalancer' in group_names"
  notify: Restart Nginx

- name: Template the web server index page
  ansible.builtin.template:
    src: index.html.j2
    dest: /var/www/html/index.html
  when: "'webservers' in group_names"

- name: Ensure Nginx is running and enabled at boot
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: yes
```

##### `roles/nginx/templates/`

* **Purpose:** This directory holds Jinja2 template files (`.j2`). Ansible uses these templates to dynamically generate configuration files.
* **`index.html.j2`:** A template for the web servers' homepages. It uses variables like `{{ server_greeting }}` to create customized content.
* **`loadbalancer.conf.j2`:** A template for the load balancer's Nginx configuration. It dynamically creates the list of backend servers by looping through the `webservers` group in our inventory.

##### `roles/nginx/handlers/main.yml`

* **Purpose:** Handlers are special tasks that only run when "notified" by another task.
* **Why it's used:** We only want to restart the Nginx service if its configuration file actually changes. This is much more efficient than restarting it on every single run. The `notify: Restart Nginx` line in the `tasks/main.yml` file triggers the handler here.

```yaml
---
- name: Restart Nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

##### `roles/nginx/defaults/main.yml`

* **Purpose:** Contains default variables for the `nginx` role. These variables have the lowest precedence and can be easily overridden.
* **Why it's used:** It's a good place to set safe defaults, like the port Nginx should listen on.

```yaml
---
nginx_port: 80
```

---

## How to Run This Project

Follow these steps in your WSL terminal.

**1. Clean Up and Create the Environment**

```bash
# Stop and remove any old containers and the network
docker stop web01 web02 lb01 jenkins && docker rm web01 web02 lb01 jenkins
docker network rm ansible-network
# Create the dedicated network for our containers
docker network create ansible-network
```

**2. Build the Custom Jenkins Image**

This command builds our custom Jenkins image, dynamically passing in the correct Group ID for Docker socket permissions.

```bash
docker build --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3) -t custom-jenkins -f Dockerfile.jenkins .
```

**3. Run All Docker Containers**

```bash
# Start the target "server" containers on the custom network
docker run -d --name web01 --network ansible-network debian:bullseye-slim sleep 3600
docker run -d --name web02 --network ansible-network debian:bullseye-slim sleep 3600
docker run -d --name lb01 --network ansible-network -p 8080:80 debian:bullseye-slim sleep 3600

# Run the Jenkins controller container, also on the custom network
docker run -d --name jenkins --network ansible-network \
  -p 8081:8080 \
  -p 50000:50000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  custom-jenkins
```

**4. Configure Jenkins**

* **Get Admin Password:** Run `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
* **Log In:** Open a browser to `http://localhost:8081` and use the password.
* **Install Plugins:** Click "Install suggested plugins".
* **Create Admin User:** Create your own permanent admin user account.
* **Create the Pipeline Job:**
    * New Item > Enter name (e.g., `ansible-from-github`) > Pipeline > OK.
    * Scroll down to the "Pipeline" section.
    * **Definition:** `Pipeline script from SCM`
    * **SCM:** `Git`
    * **Repository URL:** Enter the HTTPS URL of your GitHub repository.
    * **Branch Specifier:** `*/main`
    * **Script Path:** `Jenkinsfile`
    * Click **Save**.

**5. Run the Pipeline and Verify**

* On the job's page, click **"Build Now"**.
* After it succeeds, open a new WSL terminal and run `curl http://localhost:8080` a few times. You should see the HTML response alternate between `web01` and `web02`.
