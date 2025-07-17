# Use the official, stable Nginx image from Docker Hub.
# The 'alpine' tag means it's a very small, lightweight version.
FROM nginx:stable-alpine

# Copy our custom index.html file into the container.
# The destination path `/usr/share/nginx/html/` is the default
# web root directory for the Nginx image.
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80 to inform Docker that the container listens on this port.
# Cloud Run will use this port to send traffic to our Nginx server.
EXPOSE 80

# The default command for the nginx image is to start the server.
# We add this CMD to be explicit. The `-g "daemon off;"` argument
# is crucial for running Nginx in the foreground, which is required
# by container orchestrators like Docker and Cloud Run.
CMD ["nginx", "-g", "daemon off;"]