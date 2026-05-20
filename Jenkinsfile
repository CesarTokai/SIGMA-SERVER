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
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git submodule update --init --recursive'
            }
        }

        stage('Deploy') {
            steps {
                sshagent(['prod-ssh-key']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} "
                            cd ${DEPLOY_PATH}
                            git pull origin main
                            git submodule update --remote --merge
                            
                            CHANGED=\$(git diff --name-only HEAD~1 HEAD)
                            
                            if echo \"\$CHANGED\" | grep -q \"SIGMAV2-SERVICES\"; then
                                docker-compose up -d --build sigmav2-backend
                            fi
                            
                            if echo \"\$CHANGED\" | grep -q \"SIGMAV2-APPFRONT-END\"; then
                                docker-compose up -d --build sigmav2-frontend
                            fi
                            
                            if echo \"\$CHANGED\" | grep -q \"BD_SIGMAV2\"; then
                                docker-compose up -d --build sigmav2-db
                            fi
                            
                            if echo \"\$CHANGED\" | grep -q \"nginx\|docker-compose\"; then
                                docker-compose restart nginx_proxy
                            fi
                            
                            sleep 10
                        "
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                sh 'curl -s http://localhost/sigmav2/api/health || echo "Health check failed"'
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
