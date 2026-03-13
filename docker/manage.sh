#!/bin/sh
set -e

# 1. Check for arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <variant> {build|force-build|start|stop|kill|restart|rebuild|status|logs}"
    echo "Example: $0 alpine-basic start"
    echo "This will look for: Dockerfile.alpine-basic"
    exit 1
fi

VARIANT="$1"
COMMAND="$2"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 2. Dynamic Settings based on the Variant
DOCKERFILE="${SCRIPT_DIR}/Dockerfile.${VARIANT}"
NAME="shgittp-${VARIANT}"
IMAGE="img-${VARIANT}"
# Default to 2222, but allow override like: PORT=2223 ./manage alpine-root start
PORT="${PORT:-2222}" 

# 3. Check if the specific Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
    echo "ERROR: Could not find $DOCKERFILE"
    exit 1
fi

PUB_KEY=$(cat ~/.ssh/id_rsa.pub)

if [ -z "$PUB_KEY" ]; then
    echo "ERROR: ~/.ssh/id_rsa.pub is empty or doesn't exist"
    exit 1
fi

build() {
    echo "Building $IMAGE using $DOCKERFILE..."
    # Added -f to specify the file
    docker build -f "$DOCKERFILE" --build-arg SSH_PUB_KEY="$PUB_KEY" -t "$IMAGE" "$SCRIPT_DIR"
}

force_build() {
    echo "Force building $IMAGE using $DOCKERFILE..."
    docker build --no-cache -f "$DOCKERFILE" --build-arg SSH_PUB_KEY="$PUB_KEY" -t "$IMAGE" "$SCRIPT_DIR"
}

start() {
    if [ "$(docker ps -aq -f name=^/${NAME}$)" ]; then
        docker start "$NAME" && echo "Container $NAME started on port $PORT"
    else
        # check if port is taken
        if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
            echo "WARNING: Port $PORT is already in use."
        fi
        docker run -d -p "$PORT":22 --name "$NAME" -v "/tmp:/host/tmp:ro" "$IMAGE"
        echo "Started $NAME on localhost:$PORT"
    fi
}

stop() {
    docker stop "$NAME" 2>/dev/null || true
    echo "Stopped $NAME"
}

kill() {
    docker kill "$NAME" 2>/dev/null || true
    echo "Killed $NAME"
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

# Switch on the COMMAND ($2), not $1
case "$COMMAND" in
    build|start|stop|kill|rebuild|restart|status|logs) "$COMMAND" ;;
    force-build) force_build ;;
    *) 
        echo "Unknown command: $COMMAND"
        echo "Usage: $0 <variant> <command>"
        exit 1 
        ;;
esac
