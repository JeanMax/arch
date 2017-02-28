#!/bin/bash

WLAN=$(ip link | grep wlp | cut -f2 -d':')
test $WLAN && wifi-menu -o $WLAN || echo "No wifi hardware detected."


# NyHY2gPzELP7nbjMDTmmjiFc # NETGEAR64
