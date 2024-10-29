#!/bin/bash

# Check if the necessary parameters were passed
if [ "$#" -ne 3 ]; then
  echo "Use: $0 <ACTION (add|rm)> <NEW_IP> <UPSTREAM_NAME>"
  exit 1
fi

# Load environment variables if file exists
env_file=".env"

if [[ -f $env_file ]]; then
  set -a
  source "$env_file"
  set +a
fi

# Get parameters from the command line
ACTION=$1
NEW_IP=$2
UPSTREAM_NAME=$3

# NGINX configuration file (modify this path according to your environment)
destination=/etc/nginx/conf.d/default.conf
mounts=$(docker inspect cubiko-gateway --format '{{json .Mounts}}')
source_path=$(echo "$mounts" | grep -o '{[^}]*"Destination":"/etc/nginx/conf.d/default.conf"[^}]*}' | sed -n 's/.*"Source":"\([^"]*\)".*/\1/p')

NGINX_CONF=$source_path

# Add new IP or remove it in upstream block
function update_upstream {
  if grep -q "upstream $UPSTREAM_NAME" "$NGINX_CONF"; then
    if [ "$ACTION" == "add" ]; then
      if ! grep -q "server $NEW_IP;" "$NGINX_CONF"; then
        sed -i "/upstream $UPSTREAM_NAME {/a\    server $NEW_IP;" "$NGINX_CONF"
        echo "IP $NEW_IP added to upstream block $UPSTREAM_NAME."
      else
        echo "IP $NEW_IP is already active in the upstream block."
      fi
    elif [ "$ACTION" == "rm" ]; then
      if grep -q "server $NEW_IP;" "$NGINX_CONF"; then
        sed -i "/server $NEW_IP;/d" "$NGINX_CONF"
        echo "IP $NEW_IP has been removed from upstream block $UPSTREAM_NAME."
      else
        echo "The IP $NEW_IP is not present in the upstream block."
      fi
    else
      echo "Unrecognized action: use 'add' or 'rm'."
      exit 1
    fi
  else
    echo "The upstream block $UPSTREAM_NAME was not found in the configuration file."
  fi
}

# Run the update and restart NGINX
update_upstream
#docker restart cubiko-gateway
