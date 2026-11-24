# OpenPost for Railway: the official image, pinned by release tag and digest.
# To update: change the tag and digest below, add a CHANGELOG.md entry, merge to main.
FROM ghcr.io/getopenpost/openpost:v7.42.5@sha256:f6c92cbe6a1795049ad81c7b9a646b4e163145bbc46e35e55e539b1ede16c0d6

USER root
# su-exec drops back to the image's unprivileged "openpost" user after the
# start script has made the Railway volume writable for it.
RUN apk add --no-cache su-exec curl jq

COPY --chmod=755 railway-start.sh /usr/local/bin/railway-start.sh
COPY --chmod=755 ffmpeg-wrapper.sh /usr/local/bin/ffmpeg

ENV PORT=8080
EXPOSE 8080
WORKDIR /app
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
