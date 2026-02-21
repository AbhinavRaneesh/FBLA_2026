# FBLA_2026

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Deploying to Render

The error `ENOENT: no such file or directory, open '/opt/render/project/src/package.json'`
happens when Render treats this repo like a Node app and runs `npm install`.
This project is Flutter, so deploy it as a Docker web service instead.

### Option 1: Blueprint (recommended)

1. Push this repo with `render.yaml` and `Dockerfile`.
2. In Render, click **New +** -> **Blueprint**.
3. Select this repository and create the service.

### Option 2: Manual Web Service

1. In Render, click **New +** -> **Web Service**.
2. Select this repo.
3. Set **Environment** to **Docker**.
4. Leave build/start commands empty (Dockerfile handles both).

Render will build Flutter web in Docker and serve the generated files.
