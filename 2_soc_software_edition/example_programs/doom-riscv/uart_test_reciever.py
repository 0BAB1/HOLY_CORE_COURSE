import serial
import pygame

# --- CONFIG ---
SERIAL_PORT = "/dev/ttyUSB1"
BAUDRATE = 128000
SCREEN_WIDTH = 320
SCREEN_HEIGHT = 200

PIXEL_CHAR_WHITE = b'#'
PIXEL_CHAR_BLACK = b'&'

# --- Initialize Serial & Pygame ---
ser = serial.Serial(SERIAL_PORT, BAUDRATE, timeout=0.1)
pygame.init()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Doom UART Display")
clock = pygame.time.Clock()

current_line = 0

try:
    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                raise KeyboardInterrupt

        line = ser.readline()
        if not line or not PIXEL_CHAR_WHITE[0] in line or not PIXEL_CHAR_BLACK[0] in line:
            continue

        line = line.rstrip(b'\r\n')
        # Pad or truncate
        if len(line) < SCREEN_WIDTH:
            line += b' ' * (SCREEN_WIDTH - len(line))
        elif len(line) > SCREEN_WIDTH:
            line = line[:SCREEN_WIDTH]

        # Draw this line
        for x, ch in enumerate(line):
            color = (255, 255, 255) if ch == PIXEL_CHAR_WHITE[0] else (0, 0, 0)
            screen.set_at((x, current_line), color)

        current_line += 1

        if current_line > SCREEN_HEIGHT - 1:
            current_line = 0
            pygame.display.flip()
            clock.tick(30)  # optional limit to avoid hogging CPU

except KeyboardInterrupt:
    print("Exiting...")

finally:
    ser.close()
    pygame.quit()
