# KaamNow web app: builds the Flutter web bundle, then serves it from Caddy.
# Caddy is also the HTTPS proxy for the API (see deploy/Caddyfile, mounted at run time).
# buildpack-deps already has curl, git, xz and unzip, which Flutter needs.
FROM buildpack-deps:bookworm AS build
ARG FLUTTER_VERSION=3.50.1
RUN useradd --create-home flutter && mkdir /src && chown flutter /src
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C /opt \
    && chown -R flutter /opt/flutter
USER flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics --enable-web >/dev/null && flutter precache --web

WORKDIR /src
COPY --chown=flutter pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY --chown=flutter . .
# An empty API_BASE_URL makes the app call the server it was loaded from, so this one image
# works on any domain. Set it only if the API lives on a different host.
ARG API_BASE_URL=
ARG APP_VERSION=1.0.0
RUN flutter build web --release --no-web-resources-cdn --no-wasm-dry-run \
    --dart-define=API_BASE_URL=${API_BASE_URL} --dart-define=APP_VERSION=${APP_VERSION}

FROM caddy:2
COPY --from=build /src/build/web /srv/web
EXPOSE 80 443 443/udp
