ARG NODE_VERSION=24.15.0

FROM node:${NODE_VERSION}-alpine3.22 AS builder

ARG N8N_VERSION=stable

RUN apk add --no-cache build-base python3 && \
    npm install -g n8n@${N8N_VERSION} && \
    cd /usr/local/lib/node_modules/n8n && \
    npm rebuild sqlite3 && \
    rm -rf /root/.npm /tmp/*

FROM node:${NODE_VERSION}-alpine3.22

ARG N8N_RELEASE_TYPE=stable
ARG N8N_USER_FOLDER=/data
ARG N8N_VERSION=stable

ENV N8N_RELEASE_TYPE=${N8N_RELEASE_TYPE}
ENV N8N_USER_FOLDER=${N8N_USER_FOLDER}
ENV NODE_ENV=production
ENV SHELL=/bin/sh

RUN apk update && \
    apk upgrade --no-cache --available && \
    apk add --no-cache busybox-binsh && \
    apk --no-cache add --virtual .build-deps-fonts msttcorefonts-installer fontconfig && \
    update-ms-fonts && \
    fc-cache -f && \
    apk del .build-deps-fonts && \
    find /usr/share/fonts/truetype/msttcorefonts/ -type l -exec unlink {} \; && \
    apk add --no-cache \
    git \
    openssh \
    openssl \
    graphicsmagick=1.3.45-r0 `# pinned to avoid ghostscript-fonts (AGPL)` \
    tini \
    tzdata \
    ca-certificates \
    su-exec \
    shadow \
    libc6-compat && \
    rm -rf /tmp/* /root/.npm /root/.cache/node /opt/yarn*

COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules

WORKDIR ${N8N_USER_FOLDER}

COPY docker-entrypoint.sh /

RUN ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    mkdir -p ${N8N_USER_FOLDER}/.n8n && \
    chown -R node:node ${N8N_USER_FOLDER} && \
    rm -rf /root/.npm /tmp/*

EXPOSE 5678/tcp

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
