pipeline {
    agent any

    environment {
        DEPLOY_PATH = '/home/deployments/apps/SIGMA-SERVER'
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Deploy') {
            steps {
                sh '''
                    echo "Updating repo..."
                    docker exec sigmav2_backend bash -c "
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

    post {
        success {
            echo '✅ Deploy exitoso'
        }
        failure {
            echo '❌ Deploy fallido'
        }
    }
}
