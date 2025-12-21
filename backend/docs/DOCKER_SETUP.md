# MEWallet Backend - Docker Setup

## 📦 Upload Files to VM

From your laptop PowerShell:

```powershell
# Upload Docker files to VM
scp Dockerfile docker-compose.yml .dockerignore mewallet@YOUR_VM_IP:/home/mewallet/backend/
```

## 🐳 One-Time Docker Installation on Ubuntu VM

SSH into your VM and run:

```bash
# Update package list
sudo apt update

# Install Docker
sudo apt install -y docker.io docker-compose

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group (no sudo needed)
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
exit
```

SSH back in after logging out.

## 🚀 Build and Run (First Time)

```bash
cd /home/mewallet/backend

# Build the Docker image
docker-compose build

# Start the container (runs in background)
docker-compose up -d
```

**That's it!** Your backend is now running 24/7.

## 📋 Useful Commands

```bash
# Check if container is running
docker ps

# View logs
docker-compose logs -f

# Stop the container
docker-compose down

# Restart the container
docker-compose restart

# Update code and restart
docker-compose down
docker-compose build
docker-compose up -d

# Check container status
docker-compose ps

# See resource usage
docker stats mewallet-backend
```

## 🔄 Auto-Start on VM Reboot

Docker will automatically start your container when the VM reboots because of `restart: unless-stopped` in docker-compose.yml.

To verify Docker starts on boot:
```bash
sudo systemctl status docker
# Should show "enabled"
```

## 🔥 Quick Update Workflow

When you make code changes:

```bash
# On laptop - upload new files
scp -r *.py mewallet@YOUR_VM_IP:/home/mewallet/backend/

# On VM - restart container
cd /home/mewallet/backend
docker-compose restart
```

## ✅ Test It Works

```bash
# From VM
curl http://localhost:8000/health

# From laptop (replace with your VM IP)
curl http://YOUR_VM_IP:8000/health
```

## 🛑 Stop Everything

```bash
docker-compose down
```

## 💡 Benefits

- ✅ Runs 24/7 even when you disconnect SSH
- ✅ Auto-restarts if it crashes
- ✅ Auto-starts on VM reboot
- ✅ Easy to update and rollback
- ✅ Isolated environment
- ✅ No manual process management
