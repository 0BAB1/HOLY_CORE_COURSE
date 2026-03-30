from scapy.all import Ether, sendp, AsyncSniffer, get_if_hwaddr
import time

# ── Config ────────────────────────────────────────────────────────────────────
IFACE    = "enp0s31f6"
ETH_TYPE = 0x9000
DST_MAC  = "de:ea:be:ef:00:01"
SRC_MAC  = get_if_hwaddr(IFACE)
INTERVAL = 0.005      # seconds between frames

# Minimum Ethernet payload size = 46 bytes
ETH_PAYLOAD_MIN = 46

# ── RX callback ───────────────────────────────────────────────────────────────
def on_packet(pkt):
    if not pkt.haslayer(Ether):
        return

    payload = bytes(pkt[Ether].payload)

    # compare destination MAC
    if pkt[Ether].dst.lower() == DST_MAC.lower():
        return  # ignore this packet

    # Print raw bytes, low-level
    print("RX bytes:", " ".join(f"{b:02X}" for b in payload))

# ── Main loop ─────────────────────────────────────────────────────────────────
sniffer = AsyncSniffer(
    iface=IFACE,
    filter=f"ether proto {0x9000}",
    prn=on_packet,
    store=False,
)
sniffer.start()

tx_count = 0

print(f"Sending on {IFACE}  src={SRC_MAC}  ethertype=0x{ETH_TYPE:04X}")
print("Ctrl-C to stop\n")

try:
    while True:
        # Single uint32_t sample
        value = 0xDEADBEEF

        # Convert to big-endian bytes
        payload = bytes([
            (value >> 24) & 0xFF,
            (value >> 16) & 0xFF,
            (value >> 8) & 0xFF,
            (value >> 0) & 0xFF,
        ])

        # Pad to minimum Ethernet payload
        if len(payload) < ETH_PAYLOAD_MIN:
            payload += bytes(ETH_PAYLOAD_MIN - len(payload))

        # Create and send Ethernet frame
        pkt = Ether(dst=DST_MAC, src=SRC_MAC, type=ETH_TYPE) / payload
        sendp(pkt, iface=IFACE, verbose=False)

        tx_count += 1
        print(f"TX frame {tx_count}  payload_len={len(payload)}")

        time.sleep(INTERVAL)

except KeyboardInterrupt:
    print("\nStopped")
    sniffer.stop()