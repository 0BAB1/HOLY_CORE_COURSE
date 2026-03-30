from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, Button, Label
from textual.reactive import reactive
from textual.containers import Horizontal, Vertical
from scapy.all import Ether, sendp, AsyncSniffer, get_if_hwaddr
import math
import struct
import threading
from collections import deque
import numpy as np
import random

# ── Config ────────────────────────────────────────────────────────────────────

IFACE           = "enp0s31f6"
ETH_TYPE        = 0x9000
DST_MAC         = "de:ea:be:ef:00:01"
SRC_MAC         = get_if_hwaddr(IFACE)
ETH_PAYLOAD_MIN = 46
SCALE           = 2**31 - 1
FPS = 30


def make_frame(value: int) -> bytes:
    payload = struct.pack("<i", value)
    return payload + bytes(ETH_PAYLOAD_MIN - len(payload))


# main signal function sent for FFT to HOLY CORE
def main_signal(t):
    y = (
        1 * math.cos(t)
        + 0.2 * math.sin(7 * t)
        + 0.8 * math.sin(3 * t)
        + 0.25 * math.sin(5 * t)
    )
    return y


# ── Widgets ───────────────────────────────────────────────────────────────────

class TxPlot(Static):
    offset  = reactive(0.0)
    tx_data = reactive(list)

    def render(self) -> str:
        w = max(10, self.size.width  - 2)
        h = max(4,  self.size.height - 1)
        plot = [[" "] * w for _ in range(h)]
        mid  = h // 2

        for x in range(w):
            plot[mid][x] = "─"
        for y in range(h):
            plot[y][0] = "│"
        plot[mid][0] = "┼"

        for (xn, yn) in self.tx_data:
            px = int(xn * (w - 1))
            px = max(1, min(w - 1, px))
            py = int(mid - yn * (mid - 1))
            py = max(0, min(h - 1, py))
            plot[py][px] = "●"

        return "\n".join("".join(row) for row in plot)


class RxPlot(Static):
    # list of frames, each frame = 128 normalized values
    heatmap = reactive(list)

    def render(self) -> str:
        w = max(10, self.size.width - 2)   # time axis
        h = max(8,  self.size.height - 1)  # frequency axis

        plot = [[" "] * w for _ in range(h)]

        if not self.heatmap:
            return "\n".join("".join(row) for row in plot)

        # keep only visible frames
        frames = self.heatmap[-w:]

        for x, frame in enumerate(frames):
            for i, val in enumerate(frame):
                # map frequency bin -> vertical pixel (low freq bottom)
                y = int((1 - i / (len(frame) - 1)) * (h - 1))

                # intensity mapping
                if val > 0.8:
                    char = "█"
                elif val > 0.7:
                    char = "▓"
                elif val > 0.6:
                    char = "▒"
                elif val > 0.2:
                    char = "░"
                else:
                    char = " "

                plot[y][x] = char

        return "\n".join("".join(row) for row in plot)


# ── App ───────────────────────────────────────────────────────────────────────

class SineApp(App):
    CSS = """
    Screen {
        background: #1a1a2e;
        layout: vertical;
    }
    #title {
        text-align: center;
        color: #00ff88;
        text-style: bold;
        height: 3;
        content-align: center middle;
        width: 100%;
    }
    #status {
        text-align: center;
        color: #888888;
        height: 1;
        width: 100%;
    }
    #plots {
        height: 1fr;
        width: 100%;
    }
    .plot-panel {
        width: 50%;
        height: 100%;
        padding: 0 1;
    }
    .plot-title {
        text-align: center;
        text-style: bold;
        height: 1;
        width: 100%;
    }
    #tx-title { color: #00ff88; }
    #rx-title { color: #ff6b6b; }
    TxPlot {
        color: #00ff88;
        height: 1fr;
        width: 100%;
    }
    RxPlot {
        color: #ff6b6b;
        height: 1fr;
        width: 100%;
    }
    #controls {
        align: center middle;
        height: 3;
        width: 100%;
    }
    Button { margin: 0 2; }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        yield Label("⚡ HOLY CORE Ethernet Processing ⚡", id="title")
        yield Label("Idle — press Start", id="status")
        yield Horizontal(
            Vertical(
                Label("📤  TX — Outgoing Sine Packets", classes="plot-title", id="tx-title"),
                TxPlot(id="tx-plot"),
                classes="plot-panel",
            ),
            Vertical(
                Label("📥  RX — Frequency Heatmap", classes="plot-title", id="rx-title"),
                RxPlot(id="rx-plot"),
                classes="plot-panel",
            ),
            id="plots",
        )
        yield Horizontal(
            Button("▶  Start", id="btn-start", variant="success"),
            Button("■  Stop",  id="btn-stop",  variant="error"),
            Button("✕  Quit",  id="btn-quit",  variant="warning"),
            id="controls",
        )
        yield Footer()

    def on_mount(self) -> None:
        self._timer    = None
        self._rx_buf   = []
        self._rx_lock  = threading.Lock()
        self._rx_history = deque(maxlen=512)

        self._tx_count = 0
        self._rx_count = 0
        self._tick_idx = 0

        self._tx_history = deque(
            (max(-(2**31), min(2**31 - 1, int(main_signal(k) * SCALE))) for k in range(256)),
            maxlen=256
        )

        self._sniffer = AsyncSniffer(
            iface=IFACE,
            filter=f"ether proto {0x9000}",
            prn=self._on_packet,
            store=False,
        )
        self._sniffer.start()
        self.query_one("#status", Label).update(f"🔌 Ready on {IFACE} — press Start")

    def _on_packet(self, pkt) -> None:
        if not pkt.haslayer(Ether):
            return
        if pkt[Ether].src.lower() == SRC_MAC.lower():
            return

        payload = bytes(pkt[Ether].payload)
        if len(payload) < 128 * 4:
            return

        mags = struct.unpack_from("<128i", payload)

        # log scaling for better visuals
        frame = [math.log1p(abs(m)) for m in mags]
        max_val = max(frame) or 1
        frame = [v / max_val for v in frame]

        with self._rx_lock:
            self._rx_buf.append(frame)
            self._rx_count += 1

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-start" and self._timer is None:
            self._timer = self.set_interval(1 / FPS, self.tick)
            self.query_one("#status", Label).update(f"🟢 Running on {IFACE}")
        elif event.button.id == "btn-stop" and self._timer is not None:
            self._timer.stop()
            self._timer = None
            self.query_one("#status", Label).update(
                f"🔴 Stopped — TX: {self._tx_count}  |  RX: {self._rx_count}"
            )
        elif event.button.id == "btn-quit":
            self._sniffer.stop()
            self.exit()

    def tick(self) -> None:
        tx_plot = self.query_one("#tx-plot", TxPlot)
        rx_plot = self.query_one("#rx-plot", RxPlot)

        self._tick_idx += 1
        w = max(10, tx_plot.size.width - 2)

        t     = (self._tick_idx / w) * 4 * math.pi
        y     = main_signal(t)
        y_int = max(-(2**31), min(2**31 - 1, int(y * SCALE)))

        self._tx_history.append(y_int)

        if len(self._tx_history) == 256:
            payload = b"".join(struct.pack("<i", s) for s in self._tx_history)
            payload += bytes(max(0, ETH_PAYLOAD_MIN - len(payload)))
            pkt = Ether(dst=DST_MAC, src=SRC_MAC, type=ETH_TYPE) / payload
            sendp(pkt, iface=IFACE, verbose=False)
            self._tx_count += 1

        # update TX plot
        current_tx = list(tx_plot.tx_data)
        current_tx.append((1.0, y / 1.5))
        n = min(len(current_tx), w - 1)
        tx_plot.tx_data = [
            ((i / (n - 1)) if n > 1 else 0.5, yn)
            for i, (_, yn) in enumerate(current_tx[-n:])
        ]

        # RX handling
        with self._rx_lock:
            new_rx = list(self._rx_buf)
            self._rx_buf.clear()

        if new_rx:
            for frame in new_rx:
                self._rx_history.append(frame)
            rx_plot.heatmap = list(self._rx_history)

        self.query_one("#status", Label).update(
            f"🟢 Running — TX: {self._tx_count} frames  |  RX: {self._rx_count} frames  |  {IFACE}"
        )


if __name__ == "__main__":
    SineApp().run()