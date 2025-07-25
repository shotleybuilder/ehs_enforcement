# Docker Setup for EHS Enforcement

## The Issue

You're getting: `Cannot connect to the Docker daemon at unix:///home/jason/.docker/desktop/docker.sock. Is the docker daemon running?`

**Most Common Cause**: You have system Docker running, but Docker is trying to connect to Docker Desktop instead.

## Solution Options

### Option 1: Fix Docker Context (Most Likely Solution)

This is usually the issue if `sertantai-dev` works but `docker ps` doesn't:

```bash
# Check what contexts you have
docker context ls

# Switch to system Docker
docker context use default

# Test it works
docker ps
```

**Why this happens**: Your system has both system Docker and Docker Desktop installed, but the wrong context is active.

### Option 2: Start Docker Desktop (Alternative)

If you want to use Docker Desktop instead of system Docker:

1. **Start Docker Desktop**:
   - Look for Docker Desktop in your applications
   - Click to start it
   - Wait for it to fully load (you'll see the Docker icon in your system tray)

2. **Verify it's running**:
   ```bash
   docker ps
   ```
   Should show running containers (or empty list, not an error)

### Option 3: Install Docker Desktop (If Not Installed)

If you don't have Docker Desktop:

1. **Download Docker Desktop**:
   - Go to https://docs.docker.com/desktop/install/linux-install/
   - Download for your Linux distribution

2. **Install and start it**

### Option 4: Use System Docker (Alternative)

If you prefer system Docker instead of Desktop:

```bash
# Install Docker
sudo apt update
sudo apt install docker.io docker-compose

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group (to avoid sudo)
sudo usermod -aG docker $USER

# Log out and back in, then test
docker context use default
docker ps
```

## Quick Test

Once Docker is running, test with:

```bash
docker ps
docker --version
docker-compose --version
```

## Then Try EHS Dev Again

Once Docker is working:

```bash
ehs-dev iex
```

Should now work without the Docker daemon error!

## Troubleshooting

**If you still get permission errors:**
```bash
# Make sure you're in the docker group
groups $USER

# If 'docker' isn't listed, you need to log out and back in
```

**Check Docker Desktop status:**
- Look for Docker whale icon in system tray
- Should be running/green, not stopped/red