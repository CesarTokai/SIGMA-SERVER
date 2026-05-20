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
                    cd ${DEPLOY_PATH}
                    echo "Pulling repo..."
                    git pull origin main
                    
                    echo "Updating submodules..."
                    git submodule update --remote --merge
                    
                    echo "Rebuilding Docker..."
                    docker-compose up -d --build
                    
                    echo "Waiting..."
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
