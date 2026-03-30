from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, Button, Label
from textual.reactive import reactive
from textual.containers import Horizontal, Vertical
from scapy.all import Ether, sendp, AsyncSniffer, get_if_hwaddr
import math
import struct
import threading
from collections import deque
import random

# ── Config ────────────────────────────────────────────────────────────────────

IFACE           = "enp0s31f6"
ETH_TYPE        = 0x9000
DST_MAC         = "de:ea:be:ef:00:01"
SRC_MAC         = get_if_hwaddr(IFACE)
ETH_PAYLOAD_MIN = 46
SCALE           = 2**31 - 1
FPS             = 30


def main_signal(t):
    return (
        1.0  * math.cos(t)
    )


# ── Widgets ───────────────────────────────────────────────────────────────────

class TxPlot(Static):
    tx_data = reactive(list)

    def render(self) -> str:
        w = max(10, self.size.width  - 1)
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


class GarbagePlot(Static):
    tick_idx = reactive(0)

    def render(self) -> str:
        w = max(10, self.size.width  - 1)
        h = max(4,  self.size.height - 1)
        plot = [[" "] * w for _ in range(h)]
        mid  = h // 2

        for x in range(w):
            plot[mid][x] = "─"
        for y in range(h):
            plot[y][0] = "│"
        plot[mid][0] = "┼"

        rng = random.Random(self.tick_idx)
        for x in range(1, w):
            if rng.random() > 0.4:
                y = rng.randint(0, h - 1)
                plot[y][x] = "●"

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
        width: 1fr;
        height: 100%;
    }
    .plot-title {
        text-align: center;
        text-style: bold;
        height: 1;
        width: 100%;
    }
    #tx-title      { color: #00ff88; }
    #rx-title      { color: #ff6b6b; }
    TxPlot      { color: #00ff88; height: 1fr; width: 100%; }
    GarbagePlot { color: #ff6b6b; height: 1fr; width: 100%; }
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
                Label("TX", classes="plot-title", id="tx-title"),
                TxPlot(id="tx-plot"),
                classes="plot-panel",
            ),
            Vertical(
                Label("RX", classes="plot-title", id="rx-title"),
                GarbagePlot(id="rx-plot"),
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
        self._timer      = None
        self._tx_count   = 0
        self._tick_idx   = 0

        self._tx_history = deque(
            (max(-(2**31), min(2**31 - 1, int(main_signal(k) * SCALE))) for k in range(256)),
            maxlen=256
        )

        self.query_one("#status", Label).update("🔌 Ready — press Start")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-start" and self._timer is None:
            self._timer = self.set_interval(1 / FPS, self.tick)
            self.query_one("#status", Label).update("🟢 Running")
        elif event.button.id == "btn-stop" and self._timer is not None:
            self._timer.stop()
            self._timer = None
            self.query_one("#status", Label).update(
                f"🔴 Stopped — TX: {self._tx_count}"
            )
        elif event.button.id == "btn-quit":
            self.exit()

    def tick(self) -> None:
        tx_plot  = self.query_one("#tx-plot",  TxPlot)
        rx_plot  = self.query_one("#rx-plot",  GarbagePlot)

        self._tick_idx += 1
        w = max(10, tx_plot.size.width - 1)

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

        # TX plot rolling window
        current_tx = list(tx_plot.tx_data)
        current_tx.append((1.0, y / 1.5))
        n = min(len(current_tx), w - 1)
        tx_plot.tx_data = [
            ((i / (n - 1)) if n > 1 else 0.5, yn)
            for i, (_, yn) in enumerate(current_tx[-n:])
        ]

        # garbage RX advances every tick
        rx_plot.tick_idx = self._tick_idx

        self.query_one("#status", Label).update(
            f"🟢 Running — TX: {self._tx_count} frames  |  {IFACE}"
        )


if __name__ == "__main__":
    SineApp().run()