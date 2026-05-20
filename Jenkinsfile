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
                            git pull origin main
                            git submodule foreach -q git checkout implementacion_qr_funciones
                            git submodule foreach -q git pull origin implementacion_qr_funciones
                            docker-compose up -d --build
                        "
                        sleep 10
                        curl -s http://localhost/sigmav2/api/health || echo "Done"
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
