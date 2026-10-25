# AstrBot + NapCat all-in-one image for Render free tier
# Layer 1/2: official images; Layer 3: stack NapCat (QQ protocol) onto AstrBot (bot brain)

FROM soulter/astrbot:latest AS astrbot
FROM mlikiowa/napcat-docker:latest AS napcat

FROM astrbot

USER root
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

# QQ (electron) runtime dependencies + tooling used by napcat entrypoint / backup
RUN apt-get update && apt-get install -y --no-install-recommends \
      xvfb jq unzip rsync socat ca-certificates \
      libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
      libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 \
      libpango-1.0-0 libcairo2 libasound2 libgtk-3-0 libxss1 libxtst6 \
      libxshmfence1 libx11-xcb1 libxcursor1 libxinerama1 \
      fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# QQ + NapCat from the official napcat-docker image (keeps versions identical upstream)
COPY --from=napcat /opt/QQ /opt/QQ
COPY --from=napcat /app /app

COPY entrypoint.sh /entrypoint.sh
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/backup.sh /app/entrypoint.sh \
    && git config --global --add safe.directory '*' \
    && git config --global user.email "render-bot@users.noreply.github.com" \
    && git config --global user.name "render-backup"

# Render routes public traffic to $PORT; socat forwards it to AstrBot dashboard (6185).
# Internal ports: 6199 = AstrBot OneBot websocket (NapCat connects here), 6099 = NapCat WebUI (internal only)
EXPOSE 6185 6199 6099

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
