pipeline {
  agent any

  environment {
    REPO_URL    = 'https://github.com/AhmedKn/backend-spring.git'
    BRANCH      = 'master'

    DOCKERHUB_USER = 'i2xmortal'
    IMAGE_NAME  = 'backend-devsecops'
    IMAGE_TAG   = 'prod'

    IMAGE_FULL  = "${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

    DEPLOY_CONTAINER = 'backend'
    PORT_HOST   = '8082'
    PORT_APP    = '8082'
    HEALTH_URL  = "http://localhost:8082/api/hello"

    // Nexus
    NEXUS_URL  = 'http://nexus:8081'
    NEXUS_REPO = 'backend-devsecops'
  }

  stages {
    stage('Checkout') {
      steps {
        sh '''
          set -e
          rm -rf .git
          git init
          git remote remove origin >/dev/null 2>&1 || true
          git remote add origin https://github.com/AhmedKn/backend-spring.git
          git fetch --depth 1 origin master
          git checkout -f FETCH_HEAD
          git clean -fdx
        '''
      }
    }

    stage('Unit/Integration Tests (JUnit)') {
      steps {
        sh 'chmod +x mvnw || true'
        sh './mvnw -U clean test'
      }
    }

    stage('SonarQube Analysis') {
  steps {
    withSonarQubeEnv('sonarqube') {
      sh '''
        chmod +x mvnw || true
        ./mvnw -U -DskipTests=true verify \
          org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
          -Dsonar.projectKey=backend-devsecops \
          -Dsonar.projectName=backend-devsecops
      '''
    }
  }
}

    stage('Package') {
      steps {
        sh './mvnw -DskipTests package'
      }
    }

    stage('Deploy Artifact to Nexus (mvn deploy)') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'nexus-creds',
          usernameVariable: 'NEXUS_USER',
          passwordVariable: 'NEXUS_PASS'
        )]) {
          sh '''
            set -e
            mkdir -p ~/.m2

            cat > ~/.m2/settings.xml << EOF
<settings>
  <servers>
    <server>
      <id>nexus</id>
      <username>${NEXUS_USER}</username>
      <password>${NEXUS_PASS}</password>
    </server>
  </servers>
</settings>
EOF

            ./mvnw -DskipTests deploy \
              -DaltDeploymentRepository=nexus::default::${NEXUS_URL}/repository/${NEXUS_REPO}
          '''
        }
      }
    }

    stage('Docker Check') {
      steps {
        sh '''
          set +e
          if ! command -v docker >/dev/null 2>&1; then
            echo "DOCKER_OK=0" > docker.env
            exit 0
          fi

          docker info >/dev/null 2>&1
          if [ "$?" -eq 0 ]; then
            echo "DOCKER_OK=1" > docker.env
          else
            echo "DOCKER_OK=0" > docker.env
          fi
        '''
        script {
          def envText = readFile('docker.env').trim()
          env.DOCKER_OK = envText.split('=')[1]
          echo "Docker usable? DOCKER_OK=${env.DOCKER_OK}"
          echo "DockerHub image: ${env.IMAGE_FULL}"
        }
      }
    }

    stage('Build Docker Image') {
      when { expression { return env.DOCKER_OK == '1' } }
      steps {
        sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
        sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_FULL}"
      }
    }

    stage('Push to Docker Hub') {
      when { expression { return env.DOCKER_OK == '1' } }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-creds',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            set -e
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push "$IMAGE_FULL"
            docker logout
          '''
        }
      }
    }

    stage('Deploy on VM (Docker Compose)') {
  when { expression { return env.DOCKER_OK == '1' } }
  steps {
    sh """
      set -e
 test -f docker-compose.yml || (echo "docker-compose.yml not found in workspace" && ls -la && exit 1)
      # Ensure env vars are available to docker compose
      export DEPLOY_CONTAINER='${DEPLOY_CONTAINER}'
      export IMAGE_NAME='${IMAGE_NAME}'
      export IMAGE_TAG='${IMAGE_TAG}'
      export PORT_HOST='${PORT_HOST}'
      export PORT_APP='${PORT_APP}'

      # Stop/remove existing container(s)
      docker compose down --remove-orphans || true

      # Start with the new image tag
      docker compose up -d --remove-orphans
    """
  }
}

  }

  post {
    always {
      sh '''
        if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
          docker rm -f backend-test >/dev/null 2>&1 || true
        else
          echo "Docker not available/allowed; skipping docker cleanup"
        fi
      '''
      archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
    }
  }
}
