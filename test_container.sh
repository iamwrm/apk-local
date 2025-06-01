#!/bin/bash
set -ueo pipefail

mkdir -p .local

cat <<EOF > .local/Dockerfile
FROM debian:12-slim
RUN apt-get update && apt-get install -y curl
EOF

docker build -t debian-with-curl .local

# we use /r to run the script in the different directory than the one where the script is located, so we don't share .local accidentally
docker run -v $PWD:/app -w /r debian-with-curl \
    bash -c "
    ln -s /app/apk-local /usr/bin/apk-local
    bash /app/test.sh
    "
