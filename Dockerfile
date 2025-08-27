# Simple Dockerfile for podinfo demo application
FROM stefanprodan/podinfo:6.6.0

# Application already configured in base image
# Ports: 9898 (http), 9797 (metrics), 9999 (grpc)