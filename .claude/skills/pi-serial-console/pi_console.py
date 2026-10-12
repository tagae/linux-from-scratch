#!/usr/bin/env python3
"""Drive a Raspberry Pi's serial console (a USB-TTL adapter on the UART) from the Mac.

Standard library only: no pyserial, no terminal program. The tty is opened directly, so the driver
can reopen it at once when the adapter's driver fails a read.

    pi_console.py ports
    pi_console.py run 'uname -a' 'systemctl is-system-running'
    pi_console.py reboot [--log boot.log]
    pi_console.py watch 30

The root password is read from the repository's boot test (./test), so it has one source. Set
PI_ROOT_PASSWORD to override it.
"""
import argparse
import bisect
import errno
import glob
import os
import re
import select
import subprocess
import sys
import termios
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]

# Escape sequences systemd and the shell write to the console: colours, cursor queries (CSI n),
# terminal-name queries (DCS) and context-tracking markers (OSC).
ANSI = re.compile(rb"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)?|\x1b\[[0-9;?!]*[A-Za-z]|\x1bP[^\x1b]*\x1b\\")

# Lines in a boot log that deserve a look; the SKILL.md lists which ones are expected.
SUSPECT = re.compile(r"FAILED|Kernel panic|Oops|BUG:|Call Trace|Under-voltage|overrun|Out of memory|"
                     r"\bwarn(ing)?\b|\berror\b|\bfail(ed)?\b|unable", re.I)


def clean(data: bytes) -> str:
    """Console bytes as plain text: escape sequences dropped, line endings normalised."""
    text = ANSI.sub(b"", data).decode("utf-8", "replace")
    return text.replace("\r\r\n", "\n").replace("\r\n", "\n").replace("\r", "")


def root_password() -> str:
    if os.environ.get("PI_ROOT_PASSWORD"):
        return os.environ["PI_ROOT_PASSWORD"]
    m = re.search(r'"Password:"\s*\{\s*send "([^"\\]+)\\r"', (REPO / "test").read_text())
    if not m:
        sys.exit("cannot find the root password in ./test; set PI_ROOT_PASSWORD")
    return m.group(1)


def candidate_ports():
    # cu.* never waits for carrier detect; tty.* does.
    return sorted(glob.glob("/dev/cu.usbserial*") + glob.glob("/dev/ttyUSB*"))


def holders(port):
    """PIDs of other processes that have PORT open."""
    try:
        out = subprocess.run(["lsof", "-t", port], capture_output=True, text=True).stdout
    except FileNotFoundError:
        return []
    return [int(p) for p in out.split() if int(p) != os.getpid()]


class Console:
    def __init__(self, port, pace=0.003, raw_log=None):
        self.port = port
        self.pace = pace
        self.t0 = time.time()
        self.events = []             # (seconds, message) for every read/write error recovered from
        self.raw = bytearray()       # every byte received, in order
        self.stamps = []             # (seconds, bytes received so far) for each read
        self.pending = bytearray()   # received but not yet consumed by expect()
        self.raw_log = open(raw_log, "wb") if raw_log else None
        self.fd = None
        self.open()

    def event(self, msg):
        self.events.append((time.time() - self.t0, msg))

    def open(self):
        deadline = time.time() + 30
        while True:
            try:
                fd = os.open(self.port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
                break
            except OSError as e:
                self.event(f"open failed: {e}")
                if time.time() > deadline:
                    raise
                time.sleep(0.05)
        attrs = termios.tcgetattr(fd)
        cflag = attrs[2]
        cflag &= ~(termios.CSIZE | termios.PARENB | termios.CSTOPB | termios.HUPCL | termios.CRTSCTS)
        cflag |= termios.CS8 | termios.CLOCAL | termios.CREAD
        cc = attrs[6]
        cc[termios.VMIN] = 0
        cc[termios.VTIME] = 0
        # Raw 115200 8N1, no flow control.
        termios.tcsetattr(fd, termios.TCSANOW, [0, 0, cflag, 0, termios.B115200, termios.B115200, cc])
        termios.tcflush(fd, termios.TCIOFLUSH)
        self.fd = fd

    def reopen(self):
        try:
            os.close(self.fd)
        except OSError:
            pass
        self.open()

    def close(self):
        os.close(self.fd)
        if self.raw_log:
            self.raw_log.close()

    def elapsed(self):
        return time.time() - self.t0

    def pump(self, timeout=0.2):
        """Read what is available, waiting up to TIMEOUT seconds for the first byte."""
        try:
            ready, _, _ = select.select([self.fd], [], [], timeout)
        except OSError as e:
            self.event(f"select error: {e}")
            self.reopen()
            return 0
        if not ready:
            return 0
        try:
            data = os.read(self.fd, 65536)
        except BlockingIOError:
            return 0
        except OSError as e:
            self.event(f"read error errno={e.errno} ({errno.errorcode.get(e.errno)})")
            self.reopen()
            return 0
        if not data:
            self.event("read returned 0 bytes (EOF)")
            self.reopen()
            return 0
        self.raw += data
        self.stamps.append((self.elapsed(), len(self.raw)))
        self.pending += data
        if self.raw_log:
            self.raw_log.write(data)
            self.raw_log.flush()
        return len(data)

    def send(self, text, pace=None):
        """Write TEXT a byte at a time. The Pi Zero's UART has a 16-byte FIFO and loses input
        ("input overrun") when flooded while the CPU is busy with SD card I/O."""
        pace = self.pace if pace is None else pace
        for byte in text.encode():
            while True:
                try:
                    os.write(self.fd, bytes([byte]))
                    break
                except BlockingIOError:
                    select.select([], [self.fd], [], 0.1)
                except OSError as e:
                    self.event(f"write error errno={e.errno} ({errno.errorcode.get(e.errno)})")
                    self.reopen()
            time.sleep(pace)
            self.pump(0)

    def expect(self, pattern, timeout=30):
        """Wait for regex PATTERN in the unread input (escape sequences removed).

        Returns the text up to and including the match, or None on timeout. Text after the match
        stays unread."""
        rx = re.compile(pattern, re.S)
        end = time.time() + timeout
        while True:
            text = clean(bytes(self.pending))
            m = rx.search(text)
            if m:
                self.pending.clear()
                self.pending += text[m.end():].encode()
                return text[:m.end()]
            if time.time() > end:
                return None
            self.pump(0.2)

    def login(self):
        """Reach a root shell from a login prompt or an existing shell. Returns success."""
        for attempt in range(3):
            self.pending.clear()
            if attempt:
                # A garbled command can leave the shell inside an open quote; Ctrl-C leaves it.
                for _ in range(3):
                    self.send("\x03", pace=0.05)
                    time.sleep(0.3)
            self.send("\r")
            out = self.expect(r"login: $|[#$] $", 6)
            if out is not None:
                break
        else:
            return False
        if out.rstrip().endswith("login:"):
            self.send("root\r")
            if self.expect(r"Password: ", 15) is None:
                return False
            self.send(root_password() + "\r")
        time.sleep(2)
        self.pending.clear()
        # Long command lines would otherwise make readline redraw them in 80 columns.
        self.send('stty cols 1000; echo "<<$((6*7))>>"\r')
        return self.expect(r"<<42>>", 20) is not None

    _serial = 0

    def run(self, cmd, timeout=30):
        """Run CMD (one line) in the shell. Returns (output, exit status; None on timeout).

        The end marker is computed by the shell, so the echoed command line never matches it."""
        Console._serial += 1
        n = 100000 + Console._serial
        self.pending.clear()
        self.send(f'{cmd}; echo "<<END$((100000+{Console._serial}))>>$?"\r')
        out = self.expect(rf"<<END{n}>>(\d+)", timeout)
        if out is None:
            return clean(bytes(self.pending)), None
        m = re.search(rf"<<END{n}>>(\d+)", out)
        body = out[:m.start()]
        i = body.find('$?"')  # the end of the echoed command line
        if i != -1:
            body = body[i + 3:]
        return body.strip("\n"), int(m.group(1))

    def arrival(self, pattern):
        """Seconds since open at which text matching regex PATTERN first arrived (ignoring
        escape sequences inside it), or None."""
        raw = bytes(self.raw)
        parts, clean_pos, starts = [], 0, []   # kept segments and where each begins in both texts
        last = 0
        for m in ANSI.finditer(raw):
            parts.append(raw[last:m.start()])
            starts.append((clean_pos, last))
            clean_pos += m.start() - last
            last = m.end()
        parts.append(raw[last:])
        starts.append((clean_pos, last))
        m = re.search(pattern.encode(), b"".join(parts), re.S)
        if not m:
            return None
        i = bisect.bisect_right([s[0] for s in starts], m.end() - 1) - 1
        raw_pos = starts[i][1] + (m.end() - 1 - starts[i][0])
        j = bisect.bisect_right([s[1] for s in self.stamps], raw_pos)
        return self.stamps[j][0] if j < len(self.stamps) else None


def connect(args):
    port = args.port or os.environ.get("PI_SERIAL_PORT")
    if not port:
        found = candidate_ports()
        if len(found) != 1:
            sys.exit(f"expected one serial port, found {found or 'none'}; use --port")
        port = found[0]
    others = holders(port)
    if others:
        sys.exit(f"{port} is held by PID {others}: another terminal program would split the bytes "
                 "with this one. Ask the user to close it; do not kill it.")
    return Console(port, args.pace, args.raw_log)


def cmd_ports(args):
    for port in candidate_ports() or ["(none)"]:
        held = holders(port) if port != "(none)" else []
        print(port, f"held by PID {held}" if held else "free")


def cmd_run(args):
    c = connect(args)
    if not c.login():
        sys.exit("could not log in")
    failed = False
    for cmd in args.commands:
        out, st = c.run(cmd, args.timeout)
        print(f"$ {cmd}\n{out}\n[exit {st}]")
        failed = failed or st != 0
    if c.events:
        print("serial events:", c.events, file=sys.stderr)
    c.close()
    sys.exit(1 if failed else 0)


MILESTONES = [
    ("shutdown finished", r"reboot: Restarting system"),
    ("kernel starts", r"Linux version"),
    ("init (systemd) starts", r"Run /sbin/init"),
    ("serial getty started", r"Started\s+Serial Getty"),
    ("login prompt", r"login: $"),
]


def cmd_reboot(args):
    c = connect(args)
    if not c.login():
        sys.exit("could not log in")
    c.pending.clear()
    sent = c.elapsed()
    c.send("reboot\r")
    out = c.expect(r"Linux version.*login: $", args.timeout)
    done = out is not None
    print("captured the boot through the login prompt" if done
          else f"TIMEOUT after {args.timeout}s waiting for the login prompt")
    for name, pattern in MILESTONES:
        t = c.arrival(pattern)
        print(f"  +{t - sent:5.1f}s  {name}" if t is not None else f"     n/a   {name}")
    text = clean(bytes(c.raw))
    print(f"{len(c.raw)} bytes, {text.count('[  OK  ]')} units OK, {len(c.events)} serial read/write errors")
    print("lines worth a look:")
    for line in text.splitlines():
        if SUSPECT.search(line):
            print("  ", line.strip()[:160])
    if args.log:
        Path(args.log).write_text(text)
        print("log written to", args.log)
    c.close()
    sys.exit(0 if done else 1)


def cmd_watch(args):
    c = connect(args)
    end = time.time() + args.seconds
    while time.time() < end:
        c.pump(0.2)
    sys.stdout.write(clean(bytes(c.raw)))
    c.close()


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--port", help="serial device (default: the only /dev/cu.usbserial*)")
    p.add_argument("--pace", type=float, default=0.003, help="seconds between transmitted bytes")
    p.add_argument("--raw-log", help="also write every received byte to this file")
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("ports", help="list serial ports and who holds them").set_defaults(fn=cmd_ports)
    r = sub.add_parser("run", help="log in and run shell commands, one line each")
    r.add_argument("commands", nargs="+")
    r.add_argument("--timeout", type=int, default=60, help="seconds allowed per command")
    r.set_defaults(fn=cmd_run)
    b = sub.add_parser("reboot", help="log in, reboot, and capture the boot")
    b.add_argument("--timeout", type=int, default=300)
    b.add_argument("--log", help="write the cleaned boot text here")
    b.set_defaults(fn=cmd_reboot)
    w = sub.add_parser("watch", help="record the console without sending anything")
    w.add_argument("seconds", type=int)
    w.set_defaults(fn=cmd_watch)
    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
