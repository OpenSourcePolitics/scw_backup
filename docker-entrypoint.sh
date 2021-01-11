#!/bin/sh

if [ -d /root/.config ]; then
  rm -r /root/.config
fi

mkdir -p /root/.config/scw 
touch /root/.config/scw/config.yaml 
echo "access_key: $ACCESS_KEY\nsecret_key: $SECRET_KEY\ndefault_organization_id: $ORGANIZATION_ID\ndefault_project_id: $DEFAULT_PROJECT_ID\ndefault_zone: fr-par-1\ndefault_region: fr-par\napi_url: https://api.scaleway.com\ninsecure: false" >> /root/.config/scw/config.yaml

./main.rb