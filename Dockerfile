# Stage 1: Build
FROM golang:alpine AS builder

WORKDIR /src

# Install git (required to fetch Go dependencies)
RUN apk add --no-cache git

COPY go.mod ./
COPY main.go ./

# Fetch dependencies and build
RUN go mod tidy
RUN go build -o tui-app main.go

# Stage 2: Run
FROM alpine:latest

WORKDIR /app

# Copy the binary and script from builder
COPY --from=builder /src/tui-app .
COPY start.sh .

# Make the script executable
RUN chmod +x start.sh

# Set the entrypoint
ENTRYPOINT ["/app/start.sh"]