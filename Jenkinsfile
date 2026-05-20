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
                withCredentials([sshUserPrivateKey(credentialsId: 'jenkins-ssh', keyFileVariable: 'SSH_KEY')]) {
                    sh '''
                        ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${DEPLOY_HOST} "
                            cd ${DEPLOY_PATH}
                            
                            echo 'Pulling main...'
                            git pull origin main
                            
                            echo 'Updating SIGMAV2-SERVICES to implementacion_qr_funciones...'
                            cd SIGMAV2-SERVICES && git checkout implementacion_qr_funciones && git pull origin implementacion_qr_funciones && cd ..
                            
                            echo 'Updating SIGMAV2-APPFRONT-END to implementacion_qr_funciones...'
                            cd SIGMAV2-APPFRONT-END && git checkout implementacion_qr_funciones && git pull origin implementacion_qr_funciones && cd ..
                            
                            echo 'Rebuilding...'
                            docker compose up -d --build
                            
                            echo 'Done'
                        "
                        
                        sleep 10
                        curl -s http://localhost/sigmav2/api/health || echo "Health check done"
                    '''
                }
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
