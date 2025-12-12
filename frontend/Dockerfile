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
