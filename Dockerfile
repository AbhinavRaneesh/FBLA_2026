FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
RUN flutter config --enable-web && flutter build web --release

FROM python:3.12-alpine

WORKDIR /app

COPY --from=build /app/build/web ./build/web

ENV PORT=10000
EXPOSE 10000

CMD ["sh", "-c", "python -m http.server ${PORT} -d /app/build/web"]