# Samba Docker - Multi-User File Server

A production-ready Docker image for running Samba file server with advanced multi-user support, optimized performance, and modern SMB/CIFS protocols.

## 🚀 Features

- **Ubuntu 22.04** - Latest LTS base image
- **Multi-User Support** - Dynamic user creation via environment variables
- **Modern SMB Protocols** - SMB2/3 with encryption support
- **Shared Directory** - Single `/shared` folder accessible by all users
- **Group-Based Access** - Automatic `sambashare` group management
- **Performance Optimized** - Tuned for container environments
- **Security Enhanced** - Modern security settings and access controls
- **Supervisor Management** - Robust process monitoring and auto-restart
- **Health Checks** - Built-in container health monitoring
- **Comprehensive Logging** - Structured logging with rotation

## 📋 Architecture

```
┌─────────────────────────────────────────┐
│ Samba Docker Container                  │
├─────────────────────────────────────────┤
│ Users: alice, bob, charlie              │
│ Group: sambashare (shared access)       │
│ Directory: /shared (775 permissions)    │
│ Protocols: SMB2/3 with encryption       │
│ Management: Supervisor (nmbd + smbd)    │
└─────────────────────────────────────────┘
```

## 🚀 Quick Start

### Build the image

```bash
docker build -t samba-server ./src
```

### Single User Setup

```bash
docker run -d \
  --name samba-server \
  -p 445:445 \
  -v $(pwd)/shared:/shared \
  -e SAMBA_USERS="user1" \
  -e SAMBA_PASSWORDS="secure123" \
  samba-server
```

### Multi-User Setup (Recommended)

```bash
docker run -d \
  --name samba-multiuser \
  -p 139:139 -p 445:445 \
  -p 137:137/udp -p 138:138/udp \
  -v $(pwd)/shared:/shared \
  -e SAMBA_USERS="alice bob charlie admin" \
  -e SAMBA_PASSWORDS="alice123 bob456 charlie789 admin999" \
  -e SHARED_FOLDER_PERMISSIONS="775" \
  -e WORKGROUP="MYCOMPANY" \
  --restart unless-stopped \
  samba-server
```

## ⚙️ Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `SAMBA_USERS` | Space-separated usernames | `"sambauser"` | `"alice bob charlie"` |
| `SAMBA_PASSWORDS` | Space-separated passwords (must match user count) | `"samba123"` | `"pass1 pass2 pass3"` |
| `SHARED_FOLDER_PERMISSIONS` | Octal permissions for /shared | `755` | `775`, `777` |
| `WORKGROUP` | Windows workgroup/domain name | `WORKGROUP` | `MYCOMPANY` |
| `DEFAULT_UID` | Starting UID for created users | `1000` | `2000` |
| `DEFAULT_GID` | Starting GID for created users | `1000` | `2000` |

### 📝 Important Notes

- **User/Password Count**: Must be equal (validated at startup)
- **Permissions**: `755` (owner r/w), `775` (group r/w), `777` (all r/w)
- **UIDs**: Auto-incremented starting from `DEFAULT_UID`
- **Group Access**: All users automatically added to `sambashare` group

## 🐳 Docker Compose (Recommended)

### Production Setup

```bash
# Copy example compose file
cp docker-compose.example.yml docker-compose.yml

# Edit configuration
nano docker-compose.yml

# Deploy
docker-compose up -d

# Monitor
docker-compose logs -f samba-server
```

### Example docker-compose.yml

```yaml
version: '3.8'

services:
  samba-server:
    build: ./src
    container_name: samba-multiuser
    hostname: samba-server
    
    ports:
      - "445:445"
      - "139:139" 
      - "137:137/udp"
      - "138:138/udp"
    
    volumes:
      - ./shared:/shared
      - samba-logs:/var/log/samba
    
    environment:
      - SAMBA_USERS=alice bob charlie admin
      - SAMBA_PASSWORDS=alice123 bob456 charlie789 admin999
      - SHARED_FOLDER_PERMISSIONS=775
      - WORKGROUP=MYCOMPANY
    
    restart: unless-stopped
    
    healthcheck:
      test: ["CMD", "smbclient", "-L", "localhost", "-U", "alice%alice123", "-N"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  samba-logs:
```

## 🔌 Network Ports

| Port | Protocol | Service | Required |
|------|----------|---------|----------|
| `445` | TCP | SMB over TCP | ✅ **Essential** |
| `139` | TCP | NetBIOS Session Service | ⚡ Recommended |
| `137` | UDP | NetBIOS Name Service | ⚡ Recommended |
| `138` | UDP | NetBIOS Datagram Service | ⚡ Recommended |

**Minimal Setup**: Only port `445` is required for modern SMB3 clients.

## 💾 Volume Mounts

| Container Path | Purpose | Persistent |
|----------------|---------|------------|
| `/shared` | Main shared directory | ✅ **Required** |
| `/var/log/samba` | Samba service logs | ⚡ Recommended |
| `/var/log/supervisor` | Process management logs | 🔧 Optional |

## 🌐 Client Connection

### Windows (SMB3)

1. **File Explorer** → Address bar
2. Type: `\\<docker-host-ip>\shared`
3. Enter: Username and password
4. **Tip**: Use `\\<docker-host-ip>` to browse all shares

### macOS (SMB2/3)

1. **Finder** → `Cmd+K`
2. Enter: `smb://<docker-host-ip>/shared`
3. Select: **Registered User**
4. Enter: Username and password

### Linux (CIFS)

```bash
# Install cifs-utils
sudo apt-get install cifs-utils

# Create mount point
sudo mkdir /mnt/samba-shared

# Mount with credentials
sudo mount -t cifs //<docker-host-ip>/shared /mnt/samba-shared \
  -o username=alice,password=alice123,uid=1000,gid=1000

# Persistent mount in /etc/fstab
//<docker-host-ip>/shared /mnt/samba-shared cifs username=alice,password=alice123,uid=1000,gid=1000,iocharset=utf8 0 0
```

### Command Line Access

```bash
# List shares
smbclient -L <docker-host-ip> -U alice

# Interactive access
smbclient //<docker-host-ip>/shared -U alice

# Copy files
smbget -R smb://<docker-host-ip>/shared -U alice
```

## 📁 File System Structure

```
/shared/
├── .recycle/           # Recycle bin (if enabled)
├── alice/              # User subdirectories (optional)
├── bob/
├── charlie/
├── common/             # Shared team folders
├── projects/
└── documents/
```

**Permissions Model**:
- **Owner**: First user or root
- **Group**: `sambashare` (all users)
- **Permissions**: Configurable via `SHARED_FOLDER_PERMISSIONS`
- **Sticky Bit**: Set on directories for shared access

## 🔧 Advanced Configuration

### Custom SMB Configuration

Edit `src/smb.conf` for advanced features:

```ini
# Enable recycle bin
vfs objects = recycle
recycle:repository = .recycle
recycle:keeptree = yes

# Enable home directories
[homes]
  path = /shared/%U
  browseable = no
  writable = yes
```

### Security Enhancements

```bash
# Run with non-root user (add to docker-compose.yml)
user: "1000:1000"

# Limit container capabilities
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - DAC_OVERRIDE
  - SETGID
  - SETUID
```

## 🔍 Monitoring & Troubleshooting

### Health Check

```bash
# Container health status
docker inspect samba-server --format='{{.State.Health.Status}}'

# Manual health check
docker exec samba-server smbclient -L localhost -U alice%alice123 -N
```

### Log Analysis

```bash
# Container startup logs
docker logs samba-server

# Samba service logs
docker exec samba-server tail -f /var/log/samba/log.smbd

# User connection logs
docker exec samba-server tail -f /var/log/samba/log.*
```

### Performance Monitoring

```bash
# Active connections
docker exec samba-server smbstatus

# Resource usage
docker stats samba-server

# Process monitoring
docker exec samba-server supervisorctl status
```

### Common Issues

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Access Denied** | Authentication failures | Check username/password in logs |
| **Connection Timeout** | Cannot reach server | Verify ports 445/139 are open |
| **Permission Denied** | Cannot write files | Check `SHARED_FOLDER_PERMISSIONS` |
| **User Not Found** | Login fails | Verify user was created in startup logs |

### Debug Mode

```bash
# Enable verbose logging
docker run -e SMB_LOG_LEVEL=3 samba-server

# Interactive debugging
docker exec -it samba-server /bin/bash
testparm -s
smbclient -L localhost -U alice
```

## 📊 Performance Tuning

### Resource Limits

```yaml
# docker-compose.yml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '1.0'
    reservations:
      memory: 256M
      cpus: '0.5'
```

### Network Optimization

```ini
# smb.conf optimizations (already included)
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
max connections = 100
deadtime = 30
```

## 🔒 Security Best Practices

- ✅ **Use Strong Passwords**: Minimum 12 characters with mixed case
- ✅ **Network Isolation**: Deploy in private Docker networks
- ✅ **Regular Updates**: Rebuild images with latest security patches  
- ✅ **Access Control**: Use firewall rules to restrict access
- ✅ **Monitoring**: Enable logging and monitor access patterns
- ✅ **Backup**: Regular backups of shared data
- ❌ **Avoid**: Default passwords in production
- ❌ **Avoid**: Running containers with --privileged

## 📚 Configuration Files

| File | Purpose | Auto-Generated |
|------|---------|----------------|
| `src/Dockerfile` | Container build instructions | ❌ Manual |
| `src/entrypoint.sh` | Startup script with user creation | ✅ Optimized |
| `src/smb.conf` | Samba server configuration | ✅ Optimized |
| `src/supervisord.conf` | Process management | ✅ Optimized |
| `docker-compose.example.yml` | Production deployment template | ✅ Provided |

## 🎯 Use Cases

### Development Teams
- **Shared Projects**: Code repositories, documentation
- **Asset Storage**: Design files, media assets
- **Collaboration**: Cross-platform file sharing

### Home Labs
- **Media Server**: Movies, music, photos
- **Backup Storage**: Automated backups from multiple devices
- **IoT Data**: Sensor data collection and storage

### Small Business
- **File Server**: Replace expensive NAS solutions
- **Team Collaboration**: Document sharing and versioning
- **Remote Access**: VPN + Samba for remote file access

## 🔄 Migration Guide

### From Single User to Multi-User

1. **Backup existing data**:
   ```bash
   docker cp samba-old:/shared ./backup-shared
   ```

2. **Deploy new container**:
   ```bash
   docker-compose -f docker-compose.example.yml up -d
   ```

3. **Restore data**:
   ```bash
   docker cp ./backup-shared/. samba-multiuser:/shared/
   ```

4. **Fix permissions**:
   ```bash
   docker exec samba-multiuser chown -R root:sambashare /shared
   docker exec samba-multiuser chmod -R 775 /shared
   ```

## 🐛 Known Issues & Limitations

- **Windows 10**: May require SMB1 for discovery (security risk)
- **macOS Big Sur+**: Some connection issues with SMB2 (use SMB3)
- **Container Restart**: Samba users recreated from environment variables
- **Large Files**: >4GB files require SMB3 and proper filesystem

## 📄 License

This project is provided under MIT License for educational and development purposes.

---

**🔗 Quick Links**
- 📖 [Samba Official Documentation](https://www.samba.org/samba/docs/)
- 🐳 [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- 🔐 [SMB Security Guide](https://wiki.samba.org/index.php/Security)