#!/bin/sh
set -e

NAME="shgittp-dev-box"
IMAGE="alpine-minimal"
PORT="2222"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"  # Absolute path to script's directory

PUB_KEY=$(cat ~/.ssh/id_rsa.pub)

if [ -z "$PUB_KEY" ]; then
    echo "ERROR: ~/.ssh/id_rsa.pub is empty or doesn't exist"
    exit 1
fi

usage() {
    echo "Usage: $0 {build|force-build|start|stop|kill|restart|rebuild|status|logs}"
    exit 1
}

build() {
    docker build --build-arg SSH_PUB_KEY="$PUB_KEY" -t "$IMAGE" "$SCRIPT_DIR"
}

force_build() {
    docker build --no-cache --build-arg SSH_PUB_KEY="$PUB_KEY" -t "$IMAGE" "$SCRIPT_DIR"
}

start() {
    if [ "$(docker ps -aq -f name=^/${NAME}$)" ]; then
        docker start "$NAME" && echo "Container $NAME started"
    else
        docker run -d -p "$PORT":22 --name "$NAME" "$IMAGE"
    fi
}

stop() {
    docker stop "$NAME" 2>/dev/null || true
}

kill() {
    docker kill "$NAME" 2>/dev/null || true
}

restart() {
    stop
    docker rm "$NAME" 2>/dev/null || true
    build
    start
}

rebuild() {
    stop
    docker rm "$NAME" 2>/dev/null || true
    force_build
    start
}

status() {
    docker ps -a -f name=^/${NAME}$
}

logs() {
    docker logs "$NAME"
}

case "$1" in
    build|start|stop|kill|rebuild|restart|status|logs) "$1" ;;
    force-build) force_build ;;
    *) usage ;;
esac
