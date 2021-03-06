#!/usr/bin/env bash

set -euxo pipefail

PLUGIN_BINS="loopback portmap bandwidth aws-cni-support.sh"

for b in $PLUGIN_BINS; do
    if [ ! -f "$b" ]; then
        echo "Required $b executable not found."
        exit 1
    fi
done

HOST_CNI_BIN_PATH=${HOST_CNI_BIN_PATH:-"/host/opt/cni/bin"}

# Copy files
echo "Copying CNI plugin binaries ... "

for b in $PLUGIN_BINS; do
    # Install the binary
    install "$b" "$HOST_CNI_BIN_PATH"
done

# Configure rp_filter
echo "Configure rp_filter loose... "
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
HOST_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
PRIMARY_IF=$(ip -4 -o a | grep "$HOST_IP/" | awk '{print $2}')
sysctl -w "net.ipv4.conf.$PRIMARY_IF.rp_filter=2"
cat "/proc/sys/net/ipv4/conf/$PRIMARY_IF/rp_filter"

# Set DISABLE_TCP_EARLY_DEMUX to true to enable kubelet to pod-eni TCP communication
# https://lwn.net/Articles/503420/ and https://github.com/aws/amazon-vpc-cni-k8s/pull/1212 for background
if [ "${DISABLE_TCP_EARLY_DEMUX:-false}" == "true" ]; then
    sysctl -w "net.ipv4.tcp_early_demux=0"
else
    sysctl -e -w "net.ipv4.tcp_early_demux=1"
fi

echo "CNI init container done"
