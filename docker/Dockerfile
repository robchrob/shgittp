# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
FROM alpine:latest

RUN apk add --no-cache \
    openssh bash curl sudo less \
    git neovim

RUN ssh-keygen -A && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

RUN adduser -D -s /bin/bash dev && \
    passwd -u dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER dev
WORKDIR /home/dev
RUN mkdir -p /home/dev/.local/bin /home/dev/.bin

USER root
ARG SSH_PUB_KEY

RUN mkdir -p /home/dev/.ssh && \
    chmod 700 /home/dev/.ssh && \
    chown dev:dev /home/dev/.ssh

RUN if [ -n "$SSH_PUB_KEY" ]; then \
        echo "$SSH_PUB_KEY" > /home/dev/.ssh/authorized_keys && \
        chmod 600 /home/dev/.ssh/authorized_keys && \
        chown dev:dev /home/dev/.ssh/authorized_keys; \
    else \
        echo "WARNING: No SSH_PUB_KEY provided. SSH login will fail."; \
    fi

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
