#!/bin/bash

# Source the path.sh script to load the CONFIG_FILE and CLI_PATH variables
source /etc/hysteria/core/scripts/path.sh

# Check if WARP is active
if systemctl is-active --quiet wg-quick@wgcf.service; then
    echo "Uninstalling WARP..."
    bash <(curl -fsSL git.io/warp.sh) dwg

    # Check if the config file exists
    if [ -f "$CONFIG_FILE" ]; then
        default_config='["reject(geosite:ir)", "reject(geoip:ir)", "reject(geosite:category-ads-all)", "reject(geoip:private)", "reject(geosite:google@ads)"]'

        jq --argjson default_config "$default_config" '
            .acl.inline |= map(
                if . == "warps(all)" or . == "warps(geoip:google)" or . == "warps(geosite:google)" or . == "warps(geosite:netflix)" or . == "warps(geosite:spotify)" or . == "warps(geosite:openai)" or . == "warps(geoip:openai)" then
                    "direct"
                elif . == "warps(geosite:ir)" then
                    "reject(geosite:ir)"
                elif . == "warps(geoip:ir)" then
                    "reject(geoip:ir)"
                else
                    .
                end
            ) | .acl.inline |= ($default_config + (. - $default_config | map(select(. != "direct"))))
        ' "$CONFIG_FILE" > /etc/hysteria/config_temp.json && mv /etc/hysteria/config_temp.json "$CONFIG_FILE"

        jq 'del(.outbounds[] | select(.name == "warps" and .type == "direct" and .direct.mode == 4 and .direct.bindDevice == "wgcf"))' "$CONFIG_FILE" > /etc/hysteria/config_temp.json && mv /etc/hysteria/config_temp.json "$CONFIG_FILE"

        python3 "$CLI_PATH" restart-hysteria2 > /dev/null 2>&1
        echo "WARP uninstalled and configurations reset to default."
    else
        echo "Error: Config file $CONFIG_FILE not found."
    fi
else
    echo "WARP is not active. Skipping uninstallation."
fi
