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
                sh 'trivy --version'
                sh 'ansible-lint --version'
            }
        }

        stage('Lint and Syntax Check') {
            steps {
                sh 'echo "Running Ansible Lint..."'
                // Runs the linter against the entire project
                sh 'ansible-lint .'

                sh 'echo "Running Ansible Syntax Check..."'
                // Performs a dry-run of the playbook to check for syntax errors
                sh 'ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventory.ini --syntax-check site.yml'
            }
        }

        stage('Security Scan') {
            steps {
                sh 'echo "Running Trivy IaC Scan..."'
                // Scans all configuration files for security misconfigurations.
                // The --exit-code 1 flag makes the step fail if issues are found.
                sh 'trivy config --exit-code 1 .'
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