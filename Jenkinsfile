pipeline {
    agent any

    environment {
        DEPLOY_PATH = '/home/deployments/apps/SIGMA-SERVER'
        DEPLOY_HOST = '74.208.167.90'
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Deploy') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'deploy-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    sh '''
                        ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${DEPLOY_HOST} "
                            cd ${DEPLOY_PATH}
                            git pull origin main
                            
                            echo 'Updating submodules to implementacion_qr_funciones...'
                            git submodule foreach -q git checkout implementacion_qr_funciones
                            git submodule foreach -q git pull origin implementacion_qr_funciones
                            
                            echo 'Rebuilding Docker...'
                            docker-compose up -d --build
                        "
                        
                        sleep 10
                        echo "Health check..."
                        curl -s http://localhost/sigmav2/api/health || echo "Done"
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
