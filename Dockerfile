FROM ghcr.io/cirruslabs/flutter:3.41.1 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --no-wasm-dry-run --no-pub -v

FROM python:3.12-alpine

WORKDIR /app

COPY --from=build /app/build/web ./build/web

ENV PORT=10000
EXPOSE 10000

CMD ["sh", "-c", "python -m http.server ${PORT} -d /app/build/web"]