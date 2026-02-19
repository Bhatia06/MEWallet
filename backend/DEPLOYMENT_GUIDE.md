# MEWallet Backend Deployment Guide (Linux VM with HTTPS)

## 🚀 Quick Setup

### 1. Prerequisites on Linux VM
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install docker-compose -y

# Install Nginx
sudo apt install nginx -y

# Install Certbot (for Let's Encrypt SSL)
sudo apt install certbot python3-certbot-nginx -y
```

### 2. Upload Project to VM
```bash
# On your local machine
scp -r backend/ user@your-vm-ip:/home/user/mewallet/

# OR use git
ssh user@your-vm-ip
cd /home/user/mewallet
git clone https://github.com/your-repo/mewallet.git
cd mewallet/backend
```

### 3. Fix Port Conflict Issue

**Stop any process using port 8000:**
```bash
# Find what's using port 8000
sudo lsof -i :8000

# Kill it (replace PID with actual process ID)
sudo kill -9 <PID>

# OR stop old docker containers
docker-compose down
docker rm -f mewallet-backend
```

### 4. Configure Environment Variables
```bash
# Create .env file
cat > .env << EOF
SUPABASE_URL=your-supabase-url
SUPABASE_KEY=your-supabase-key
JWT_SECRET_KEY=your-secret-key-here
PYTHONUNBUFFERED=1
EOF
```

### 5. Start Backend with Docker
```bash
docker-compose up -d --build

# Check logs
docker logs mewallet-backend -f

# Verify it's running
curl http://localhost:8000/health
```

### 6. Setup Nginx Reverse Proxy

**Copy nginx configuration:**
```bash
sudo cp nginx.conf /etc/nginx/sites-available/mewallet
sudo ln -s /etc/nginx/sites-available/mewallet /etc/nginx/sites-enabled/

# IMPORTANT: Edit the file and replace 'your-domain.com' with your actual domain
sudo nano /etc/nginx/sites-available/mewallet
```

**Test nginx configuration:**
```bash
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### 7. Setup SSL Certificate (Let's Encrypt)
```bash
# Get SSL certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Auto-renewal is setup automatically. Test it:
sudo certbot renew --dry-run
```

### 8. Open Firewall Ports
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 9. Update Mobile App Config

Update `mobile_app/lib/utils/config.dart`:
```dart
static const String baseUrl = 'https://your-domain.com';
```

---

## 🔧 Troubleshooting

### Port 8000 Already in Use
```bash
# Option 1: Find and kill process
sudo lsof -i :8000
sudo kill -9 <PID>

# Option 2: Stop Docker container
docker stop mewallet-backend
docker rm mewallet-backend

# Option 3: Change port in docker-compose.yml
# Change "127.0.0.1:8000:8000" to "127.0.0.1:8001:8000"
```

### Container Won't Start
```bash
# Check logs
docker logs mewallet-backend

# Check container status
docker ps -a | grep mewallet

# Rebuild completely
docker-compose down
docker system prune -a
docker-compose up -d --build
```

### Nginx Not Working
```bash
# Check nginx status
sudo systemctl status nginx

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

### SSL Certificate Issues
```bash
# Check certificate
sudo certbot certificates

# Renew manually
sudo certbot renew

# If renewal fails, delete and recreate
sudo certbot delete
sudo certbot --nginx -d your-domain.com
```

### Database Issues
```bash
# Check if wallet.db exists
ls -la /path/to/backend/wallet.db

# Check permissions
sudo chmod 666 wallet.db

# Or use volume mount in docker-compose
```

---

## 📊 Monitoring

### Check if backend is running:
```bash
# Via docker
docker ps | grep mewallet

# Via curl
curl https://your-domain.com/docs

# Check logs
docker logs mewallet-backend --tail 100 -f
```

### Check resources:
```bash
# CPU/Memory usage
docker stats mewallet-backend

# Disk usage
df -h
docker system df
```

---

## 🔄 Update Deployment

```bash
# Pull latest code
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose up -d --build

# Or without downtime
docker-compose up -d --build --force-recreate
```

---

## 🔒 Security Checklist

- [ ] Firewall configured (only ports 80, 443, 22 open)
- [ ] SSL certificate installed and auto-renewing
- [ ] Database file has proper permissions
- [ ] Environment variables stored securely (.env not in git)
- [ ] JWT secret is strong and unique
- [ ] Nginx configured with security headers
- [ ] Docker containers restart on failure
- [ ] Logs are being written and rotated
- [ ] Regular backups of wallet.db configured

---

## 🎯 Quick Commands Reference

```bash
# Start backend
docker-compose up -d

# Stop backend
docker-compose down

# View logs
docker logs mewallet-backend -f

# Restart
docker-compose restart

# Rebuild
docker-compose up -d --build

# Check status
docker ps

# SSH to container
docker exec -it mewallet-backend bash

# Backup database
docker cp mewallet-backend:/app/wallet.db ./backup-$(date +%Y%m%d).db
```

---

## 📱 Test Your Deployment

1. **Backend Health Check:**
   ```bash
   curl https://your-domain.com/health
   ```

2. **API Documentation:**
   Visit: `https://your-domain.com/docs`

3. **WebSocket Test:**
   ```bash
   wscat -c wss://your-domain.com/ws
   ```

4. **Mobile App Connection:**
   Update config.dart and test registration/login

---

## 🆘 Need Help?

If you're still getting errors:

1. Share the output of:
   ```bash
   docker logs mewallet-backend
   sudo tail -f /var/log/nginx/error.log
   docker ps -a
   sudo lsof -i :8000
   ```

2. Check if domain DNS is pointed to your VM IP:
   ```bash
   nslookup your-domain.com
   ```

3. Verify Docker is running:
   ```bash
   sudo systemctl status docker
   ```
