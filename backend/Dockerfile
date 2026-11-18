FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o /app/bin/bankos_server
RUN dart compile exe bin/webhook_sink.dart -o /app/bin/webhook_sink

FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/bin/bankos_server /app/bin/bankos_server
COPY --from=build /app/bin/webhook_sink /app/bin/webhook_sink

EXPOSE 8080

CMD ["/app/bin/bankos_server"]
