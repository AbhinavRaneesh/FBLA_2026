FROM ghcr.io/cirruslabs/flutter:3.41.1 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --no-wasm-dry-run --no-pub --dart2js-optimization O2 --no-source-maps

FROM python:3.12-alpine

WORKDIR /app

COPY --from=build /app/build/web ./build/web

ENV PORT=10000
EXPOSE 10000

CMD ["sh", "-c", "python -m http.server ${PORT} -d /app/build/web"]
flutter run --dart-define=GEMINI_API_KEY=AIzaSyBGc2GDnEbFRlGauE7xc1FDfvnTO5PH-YU --dart-define=GEMINI_MODEL=gemini-2.5-flash