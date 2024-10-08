#!/bin/bash
# https://github.com/aoudiamoncef/ubuntu-sshd

# Set default values for SSH_USERNAME and PASSWORD if not provided
: ${SSH_USERNAME:=ubuntu}
: ${PASSWORD:=ubuntu}

# Create the user with the provided username and set the password
if id "$SSH_USERNAME" &>/dev/null; then
    echo "User $SSH_USERNAME already exists"
    echo "$SSH_USERNAME:$PASSWORD" | chpasswd
    echo "User $SSH_USERNAME set with the provided password"
else
    useradd -ms /bin/bash "$SSH_USERNAME"
    echo "$SSH_USERNAME:$PASSWORD" | chpasswd
    echo "User $SSH_USERNAME created with the provided password"
fi

# Set root with unsafe password
echo "root:root" | chpasswd
echo "User root set with root:root"

# Set the authorized keys from the AUTHORIZED_KEYS environment variable (if provided)
if [ -n "$AUTHORIZED_KEYS" ]; then
    mkdir -p /home/$SSH_USERNAME/.ssh
    echo "$AUTHORIZED_KEYS" > /home/$SSH_USERNAME/.ssh/authorized_keys
    chown -R $SSH_USERNAME:$SSH_USERNAME /home/$SSH_USERNAME/.ssh
    chmod 700 /home/$SSH_USERNAME/.ssh
    chmod 600 /home/$SSH_USERNAME/.ssh/authorized_keys
    echo "Authorized keys set for user $SSH_USERNAME"
fi

# Setup Tailscale
# https://tailscale.com/kb/1107/heroku
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --state=mem: &
tailscale up --authkey="${TS_AUTHKEY}?preauthorized=true&ephemeral=true" --hostname=${TS_HOSTNAME} --advertise-exit-node=true --ssh=true --accept-dns --advertise-tags=tag:container
tailscale set --webclient=true --auto-update=true --posture-checking=true
tailscale down
tailscale up
export ALL_PROXY=socks5://localhost:1055/

# Unset ENVs
unset TS_HOSTNAME
unset TS_AUTHKEY
unset SSH_USERNAME
unset PASSWORD
unset AUTHORIZED_KEYS

# Start the SSH server
exec /usr/sbin/sshd -D
