pipeline {
    agent any

    environment {
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
                    echo "Clonando/Actualizando repo en workspace..."
                    cd ${WORKSPACE}
                    
                    echo "Sincronizando a servidor..."
                    docker exec sigmav2_backend pwd > /dev/null 2>&1 && \
                    docker exec -w ${DEPLOY_PATH} sigmav2_backend git pull origin main && \
                    docker exec -w ${DEPLOY_PATH} sigmav2_backend git submodule update --remote --merge && \
                    docker exec -w ${DEPLOY_PATH} sigmav2_backend docker-compose up -d --build
                    
                    sleep 10
                    echo "Health check..."
                    curl -s http://localhost/sigmav2/api/health || echo "Done"
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
