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
                    # Decodifica la key
                    echo "LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUFNd0FBQUF0emMyZ3RaVwpReU5UVXhPUUFBQUNBWnlnQjNnSzFMOFlkN1JBNlZIK1pTWXpnQzFla25hK3BMR3dTYUNDUXdCUUFBQUpqV2YwNFoxbjlPCkdRQUFBQXR6YzJndFpXUXlOVFV4T1FBQUFDQVp5Z0IzZ0sxTDhZZDdSQTZWSCtaU1l6Z0MxZWtuYStwTEd3U2FDQ1F3QlEKQUFBRURlZFpYbEEyQkx3SURXeFdhQ1psTjFwK25UNnFQYktIYnlFVjQ0RElQaUhSbktBSGVBclV2eGgzdEVEcFVmNWxKagpPQUxWNlNkcjZrc2JCSm9JSkRBRkFBQUFEbXBsYm10cGJuTXRaR1Z3Ykc5NUFRSURCQVVHQnc9PQotLS0tLUVORCBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0K" | base64 -d > /tmp/id_rsa
                    chmod 600 /tmp/id_rsa
                    
                    # SSH con la key decodificada
                    ssh -i /tmp/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${DEPLOY_USER}@${DEPLOY_HOST} "
                        cd ${DEPLOY_PATH}
                        git pull origin main
                        git submodule update --remote --merge
                        docker-compose up -d --build
                        sleep 10
                        curl -s http://localhost/sigmav2/api/health || echo 'Health check done'
                    "
                    
                    rm -f /tmp/id_rsa
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
