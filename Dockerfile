# Use Nginx to serve static content
FROM nginx:alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy Flutter web build output
COPY build/web /usr/share/nginx/html

# Optional: Custom nginx config (e.g. for routing)
# COPY nginx.conf /etc/nginx/nginx.conf
