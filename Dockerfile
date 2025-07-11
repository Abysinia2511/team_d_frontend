# Use official Flutter image to build the web app
FROM ghcr.io/cirruslabs/flutter:3.22.0 AS build

WORKDIR /app

# Copy project files
COPY . .

# Enable web support and install dependencies
RUN flutter channel stable \
  && flutter upgrade \
  && flutter config --enable-web \
  && flutter pub get

# Build the Flutter Web app
RUN flutter build web --release

# Stage 2: Serve with NGINX
FROM nginx:stable-alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy Flutter web build to NGINX public directory
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy custom nginx config (optional)
# COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

