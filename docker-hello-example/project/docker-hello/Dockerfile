# Use the same slim image you're already on
FROM python:3.9-slim

# Set a working directory
WORKDIR /app

# Copy the script into the container
COPY hello.py .

# Ensure any stdout is immediately available via "docker logs"
ENV PYTHONUNBUFFERED=1

# Run the script when the container starts
CMD ["python", "hello.py"]
