#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
BE="$ROOT/backend"
FE="$ROOT/frontend"
[ -d "$BE" ] || { echo "Missing backend: $BE"; exit 1; }
[ -d "$FE" ] || { echo "Missing frontend: $FE"; exit 1; }

# ---------- Backend Dockerfile ----------
cat > "$BE/Dockerfile" <<'DOCKER'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY . /app

ENV PYTHONUNBUFFERED=1
EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKER

cat > "$BE/.dockerignore" <<'IGN'
__pycache__/
*.pyc
*.pyo
*.pyd
.venv/
venv/
.env
*.log
data/*.db
data/*.db-journal
IGN

# ---------- Frontend Dockerfile ----------
cat > "$FE/Dockerfile" <<'DOCKER'
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json /app/
RUN npm install

COPY . /app
ARG VITE_BACKEND_URL=http://127.0.0.1:8000
ENV VITE_BACKEND_URL=$VITE_BACKEND_URL

RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
DOCKER

cat > "$FE/.dockerignore" <<'IGN'
node_modules/
dist/
.env
*.log
IGN

# ---------- docker-compose (for server / laptop, not Termux) ----------
cat > "$ROOT/docker-compose.yml" <<'YML'
services:
  backend:
    build:
      context: ./backend
    ports:
      - "8000:8000"
    environment:
      - PYTHONUNBUFFERED=1
    volumes:
      - station_data:/app/data

  frontend:
    build:
      context: ./frontend
      args:
        - VITE_BACKEND_URL=http://backend:8000
    ports:
      - "8080:80"
    depends_on:
      - backend

volumes:
  station_data:
YML

echo "== Docker deploy pack applied =="
echo "Files:"
echo "  backend/Dockerfile, backend/.dockerignore"
echo "  frontend/Dockerfile, frontend/.dockerignore"
echo "  docker-compose.yml"
echo
echo "Usage on a Docker-capable machine (server/laptop):"
echo "  cd station_root"
echo "  docker compose up --build"
echo "Open:"
echo "  Frontend: http://127.0.0.1:8080"
echo "  Backend:  http://127.0.0.1:8000/health"
