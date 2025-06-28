// Jenkinsfile (Declarative Pipeline)
pipeline {
    agent any
    stages {
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
