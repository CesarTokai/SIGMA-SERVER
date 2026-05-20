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
                sshagent(['prod-ssh-key']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} "
                            cd ${DEPLOY_PATH}
                            echo 'Pulling main repo...'
                            git pull origin main
                            
                            echo 'Updating submodules...'
                            git submodule update --remote --merge
                            
                            echo 'Rebuilding containers...'
                            docker-compose up -d --build
                            
                            echo 'Waiting for services...'
                            sleep 10
                            
                            echo 'Checking health...'
                            curl -s http://localhost/sigmav2/api/health || echo 'Health check completed'
                        "
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '✅ Deploy exitoso'
        }
        failure {
            echo '❌ Deploy fallido'
        }
    }
}
