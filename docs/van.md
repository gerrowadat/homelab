Campervan Notes
---------------

work in progress! This is the setup in the campervan, which is within range of the home wifi most of the time, unless I'm on the road.

Hardware Setup
--------------

4G Internet - [Kuma Connect Play](https://www.amazon.co.uk/KUMA-CONNECT-PLAY-Unlocked-Motorhome/dp/B09B1XFY3K/ref=sr_1_2?keywords=kuma%2Bconnect%2Bplay&qid=1683036931&sprefix=kuma%2Caps%2C89&sr=8-2&th=1)

WiFi Dongle (with antenna connectors) - [BrosTrend](https://www.amazon.co.uk/dp/B07FCN6WGX?psc=1&ref=ppx_yo2ov_dt_b_product_details)
```
root@vannu:/home/doc# lsusb
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 001 Device 003: ID 0bda:b812 Realtek Semiconductor Corp. RTL88x2bu [AC1200 Techkey]
```

External 4G/WiFi Antenna - [Poynting 5-in-1](https://www.amazon.co.uk/dp/B08GCV9JBF?ref=ppx_yo2ov_dt_b_product_details&th=1) (This has 2 SMA for the 4G router, and 2 for leeching wifi via the USB dongle as a backup.)

RPi connected to the wifi dongle, and via ethernet to the 4g router. This has a few jobs:
  - Collect Various Telemetry (not documented here).
  - Probably act as the gateway and determine which connection to use for clients somehow.
  - Expose the dodgy reversing camera feed without having to connect to its stupid wifi network.

Err toward using the wifi if there's a stable connection, since the 4G plan has limited throughput.

Software Setup
--------------

USB wifi dongle: https://github.com/cilynx/rtl88x2bu
