pipeline {
    agent any
    triggers {
        pollSCM('H/5 * * * *')
    }

    stages {
        stage('Checkout pkgsrc') {
            steps {
                script {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: '*/trunk']],
                        userRemoteConfigs: [[
                            url: 'https://github.com/netbsd/pkgsrc.git'
                        ]]
                    ])
                }
            }
        }
        stage('Build') {
            steps {
                sh 'pwd; ls; ls ..'
            }
        }
    }
    post {
        always {
            sh 'echo "debug worked"'
        }
    }
}
