#!/usr/bin/env groovy

stage "hello"
node any {
    checkout scm
    sh "echo hello"
}

pipeline {
    agent any
    triggers {
        pollSCM('H/5 * * * *')
    }
    checkout scmGit(branches: [[name: '*/trunk']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/netbsd/pkgsrc']])

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
