pipeline {
    agent any

    environment {
        DEPLOY_USER = 'root'
        DEPLOY_HOST = '74.208.167.90'
        DEPLOY_PATH = '/home/deployments/apps/SIGMA-SERVER'
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Deploy') {
            steps {
                sh '''
                    ssh -i /var/jenkins_home/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${DEPLOY_USER}@${DEPLOY_HOST} "
                        cd ${DEPLOY_PATH}
                        git pull origin main
                        git submodule update --remote --merge
                        docker-compose up -d --build
                        sleep 10
                        curl -s http://localhost/sigmav2/api/health || echo 'Health check done'
                    "
                '''
            }
        }
    }

    post {
        success {
            echo '✅ Deploy OK'
        }
        failure {
            echo '❌ Deploy FAILED'
        }
    }
}
