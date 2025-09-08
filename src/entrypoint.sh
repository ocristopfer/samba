#!/bin/bash
set -e

# Function for logging with timestamps
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Environment variables with default values
SAMBA_USERS=${SAMBA_USERS:-"sambauser"}
SAMBA_PASSWORDS=${SAMBA_PASSWORDS:-"samba123"}
WORKGROUP=${WORKGROUP:-WORKGROUP}
SHARED_FOLDER_PERMISSIONS=${SHARED_FOLDER_PERMISSIONS:-755}
DEFAULT_UID=${DEFAULT_UID:-1000}
DEFAULT_GID=${DEFAULT_GID:-1000}

log "Starting Samba configuration with multiple users support"

# Function to create system user
create_system_user() {
    local username=$1
    local uid=$2
    local gid=$3
    
    if ! id "$username" &>/dev/null; then
        log "Creating system user: $username with UID: $uid"
        
        # Create group if it doesn't exist
        if ! getent group "$username" &>/dev/null; then
            groupadd -g "$gid" "$username" 2>/dev/null || groupadd "$username"
        fi
        
        # Create user with specific UID or let system assign one
        if [ "$uid" != "auto" ]; then
            useradd -r -u "$uid" -g "$username" -s /bin/false -d /var/lib/samba "$username" 2>/dev/null || \
            useradd -r -g "$username" -s /bin/false -d /var/lib/samba "$username"
        else
            useradd -r -g "$username" -s /bin/false -d /var/lib/samba "$username"
        fi
        
        # Add user to sambashare group
        usermod -a -G sambashare "$username" 2>/dev/null || true
    else
        log "System user $username already exists"
    fi
}

# Function to create samba user
create_samba_user() {
    local username=$1
    local password=$2
    
    log "Configuring Samba user: $username"
    
    # Add user to Samba database
    echo -e "$password\n$password" | smbpasswd -a -s "$username" 2>/dev/null || {
        log "Warning: Failed to add $username to Samba database, user might already exist"
        echo -e "$password\n$password" | smbpasswd -s "$username" 2>/dev/null || true
    }
    
    # Enable user
    smbpasswd -e "$username" 2>/dev/null || log "Warning: Could not enable user $username"
}

# Create sambashare group for shared access
if ! getent group sambashare &>/dev/null; then
    log "Creating sambashare group"
    groupadd sambashare
fi

# Convert space-separated lists to arrays
IFS=' ' read -ra USER_ARRAY <<< "$SAMBA_USERS"
IFS=' ' read -ra PASS_ARRAY <<< "$SAMBA_PASSWORDS"

# Validate user and password count match
if [ ${#USER_ARRAY[@]} -ne ${#PASS_ARRAY[@]} ]; then
    log "ERROR: Number of users (${#USER_ARRAY[@]}) doesn't match number of passwords (${#PASS_ARRAY[@]})"
    exit 1
fi

log "Creating ${#USER_ARRAY[@]} users"

# Create users
for i in "${!USER_ARRAY[@]}"; do
    username="${USER_ARRAY[$i]}"
    password="${PASS_ARRAY[$i]}"
    uid=$((DEFAULT_UID + i))
    gid=$((DEFAULT_GID + i))
    
    # Skip empty usernames
    if [ -z "$username" ] || [ -z "$password" ]; then
        log "Skipping empty username or password at index $i"
        continue
    fi
    
    log "Processing user $((i+1))/${#USER_ARRAY[@]}: $username"
    
    # Create system user
    create_system_user "$username" "$uid" "$username"
    
    # Create samba user  
    create_samba_user "$username" "$password"
done

# Create and configure shared directory
log "Setting up shared directory: /shared"
mkdir -p /shared

# Set ownership to first user or sambauser, and sambashare group
FIRST_USER="${USER_ARRAY[0]:-sambauser}"
if id "$FIRST_USER" &>/dev/null; then
    chown -R "$FIRST_USER":sambashare /shared
else
    chown -R root:sambashare /shared
fi

# Set permissions
chmod -R "$SHARED_FOLDER_PERMISSIONS" /shared

# Ensure sambashare group has write access
chmod g+w /shared
find /shared -type d -exec chmod g+s {} \; 2>/dev/null || true

log "Shared directory permissions set to $SHARED_FOLDER_PERMISSIONS"
log "Directory ownership: $(ls -ld /shared | awk '{print $3":"$4}')"

# Update workgroup in smb.conf if needed
if [ "$WORKGROUP" != "WORKGROUP" ] && [ -f /etc/samba/smb.conf ]; then
    log "Updating workgroup to: $WORKGROUP"
    sed -i "s/workgroup = WORKGROUP/workgroup = $WORKGROUP/" /etc/samba/smb.conf
fi

# Validate Samba configuration
log "Validating Samba configuration"
if testparm -s > /dev/null 2>&1; then
    log "Samba configuration is valid"
else
    log "ERROR: Invalid Samba configuration"
    testparm -s
    exit 1
fi

# Create necessary directories
log "Creating necessary directories"
mkdir -p /var/log/samba /run/samba /var/lib/samba/private
touch /var/log/samba/log.nmbd /var/log/samba/log.smbd

# Set proper permissions for samba directories
chown -R root:root /var/log/samba /run/samba /var/lib/samba
chmod 755 /var/log/samba /run/samba
chmod 700 /var/lib/samba/private

# Display final user information
log "=== User Summary ==="
for username in "${USER_ARRAY[@]}"; do
    if [ -n "$username" ] && id "$username" &>/dev/null; then
        USER_UID=$(id -u "$username")
        USER_GID=$(id -g "$username")
        USER_GROUPS=$(groups "$username" | cut -d: -f2-)
        log "User: $username (UID: $USER_UID, GID: $USER_GID, Groups:$USER_GROUPS)"
    fi
done

# Cleanup function for graceful shutdown
cleanup() {
    log "Received shutdown signal, stopping services..."
    supervisorctl shutdown 2>/dev/null || true
    exit 0
}

# Setup signal handling
trap cleanup SIGTERM SIGINT

# Verify supervisor configuration exists
if [ ! -f /etc/supervisor/conf.d/supervisord.conf ]; then
    log "ERROR: supervisord.conf not found"
    exit 1
fi

# Start services
log "Starting Samba services via Supervisor"
log "Access the share at: \\\\<host-ip>\\shared"
log "Available users: ${USER_ARRAY[*]}"

# Start supervisor in foreground
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf