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

## Core Concepts Explained

* **Docker:** A platform used to create and run applications in lightweight, isolated environments called containers. We use Docker to simulate our entire infrastructure (`web01`, `web02`, `lb01`, `jenkins`) on a single local machine.
* **Ansible:** An open-source, agentless automation tool. It connects to our target containers and uses a set of instructions (playbooks) to install and configure software, like the Nginx web server.
* **Jenkins:** An open-source automation server that acts as our CI/CD orchestrator. It clones this repository and executes the `Jenkinsfile` to run the pipeline stages in sequence.
* **Pipeline as Code:** The practice of defining our deployment pipeline in a text file (`Jenkinsfile`). This makes our CI/CD process transparent, repeatable, and version-controlled alongside our application code.

---

## Project Structure

This project uses a standard, best-practice directory structure for Ansible.

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

---

## How to Run This Project

Follow these steps in a Linux-based terminal (like WSL on Windows).

### Prerequisites

* **Docker** and **Docker Compose** must be installed.
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
    7.  **Repository URL:** Enter the HTTPS URL of your GitHub repository (e.g., `https://github.com/mohdtarique/ansible-cicd-lab.git`).
    8.  **Branch Specifier:** Ensure it is set to `*/main`.
    9.  **Script Path:** Ensure it is `Jenkinsfile`.
    10. Click **Save**.

### Step 5: Run the Pipeline and Verify

* On the job's page, click **"Build Now"**.
* Watch the pipeline execute through all its stages in the "Stage View".
* After it succeeds, open a new terminal and run `curl http://localhost:8080` a few times. You should see the HTML response alternate between `web01` and `web02`.

---

## Pipeline Stages Explained

The `Jenkinsfile` defines the following stages:

1.  **Initialize:** A simple startup stage that confirms the versions of Ansible and Docker available to the Jenkins agent.
2.  **Lint and Syntax Check:** Performs static code analysis on the Ansible code. It runs `ansible-lint` to check for best practices and `--syntax-check` to validate the playbook logic. This catches errors early.
3.  **Security Scan:** Uses `trivy config` to scan all Infrastructure as Code files for security misconfigurations. The pipeline is configured with a custom threshold: it will only fail if Trivy finds `CRITICAL` issues in more than two files.
4.  **Run Ansible Playbook:** If all previous checks pass, this stage executes the main `site.yml` playbook, which provisions and configures the running containers.
5.  **Verify Deployment:** A final smoke test that runs `curl` against the load balancer to confirm that the environment is up and serving requests.