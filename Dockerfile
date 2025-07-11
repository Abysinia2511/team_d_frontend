# Stage 1: Build Flutter web app
FROM ghcr.io/cirruslabs/flutter:3.22.0 AS build

WORKDIR /app

COPY . .

RUN flutter config --enable-web \
  && flutter pub get \
  && flutter build web --release

# Stage 2: Serve with nginx
FROM nginx:stable-alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
