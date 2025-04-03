#!/usr/bin/env groovy

pipeline {
    agent none
    stages {
        stage('Build matrix') {
            matrix {
                axes {
                    axis {
                        name 'LABEL'
                        values 'centos', 'smartos'
                    }
                }
                stages {
                    stage('Execute on ${LABEL}') {
                        agent { node { label "${LABEL}" } }
                        steps {
                            echo "Running on ${LABEL}"
                            checkout scm
                            sh 'env'
                            sh 'pwd; ls; ls ..'
                        }
                    }
                }
            }
        }
    }
}
