[README.md](https://github.com/user-attachments/files/22715245/README.md)
My6PrivateAI - Phone-first private AI orchestration repo

Included:
- server/ : FastAPI backend and Dockerfile
- scripts/ : placeholder conversion script for CI
- .github/workflows/ci-deploy.yml : GitHub Actions workflow
- ios_app/ : SwiftUI app skeleton

Quick start:
1) Create a new GitHub repo and push this content.
2) Add repo secrets: HF_TOKEN (if needed), MY6_API_KEY, GHCR_TOKEN or use GitHub Packages, FLY_API_TOKEN (optional).
3) Install app on iPhone (Xcode required for device install) or use TestFlight.
4) Enter your GitHub PAT in the app and Trigger Build to start CI.
5) CI will produce artifacts and deploy the server container.
6) In the app set the backend host and API key, then Start the runtime and watch logs.
