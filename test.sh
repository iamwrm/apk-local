mkdir -p .local

cat <<EOF > .local/Dockerfile
FROM debian:12-slim
RUN apt-get update && apt-get install -y curl
EOF

docker build -t debian-with-curl .local

docker run -v $PWD:/app -w /r debian-with-curl \
    bash -c "/app/apk-local manager add gcc && /app/apk-local env gcc --version"
