"""Mininet Node of SimpleSwitch.

This class represents a Mininet node specifically for the SimpleSwitch.
It inherits from `mininet.node.Switch` and is designed to integrate Bmv2-based
simulations within a Mininet environment.

Typical usage example:

    net.addSwitch("foo", cls=SimpleSwitch)
"""

import os
import socket
import threading
from subprocess import PIPE, Popen
from typing import Literal, TextIO, Union

from mininet.link import Intf
from mininet.log import debug, error, info
from mininet.node import Switch

from p4ws.targets import bmv2


class SimpleSwitch(Switch):
    """Mininet Node of SimpleSwitch.

    This class represents a Mininet node specifically for the SimpleSwitch.
    It inherits from `mininet.node.Switch` and is designed to integrate Bmv2-based
    simulations within a Mininet environment.

    Typical usage example:

        net.addSwitch("foo", cls=SimpleSwitch)

    Attributes
    ----------
    p4_target_conf : str
        Path to target configuration.
    listenPort : int
        TCP port on which to run the Thrift runtime server.
    nanolog_sock : str | None
        IPC socket to use for nanomsg pub/sub logs, None for no logging.
    log_console : bool
        Log to console (stdout).
    log_file : str | None
        File to which logs are written, None for stdout.
    log_level : Literal["trace", "debug", "info", "warn", "error", "off"]
        Logging level.
    log_flush : bool
        Flush to disk after every log message.
    log_dump_packet_data : int
        Specify how many bytes of packet data to dump upon receiving & sending a packet.
    pcaps_dir : str | None
        Directory to write pcap files of incoming and outgoing packets, None for current directory.
    sw_stdout : TextIO | int | None
         Standard output for model, str for a file, see Popen for more details.
    sw_stderr : TextIO | int | None
        Standard error for model, str for a file, see Popen for more details.
    """

    listen_port_base = 9090

    def __init__(self, name,
                 p4_target_conf: str,
                 *,
                 nanolog_sock: Union[str, None] = None,
                 log_console: bool = False,
                 log_file: Union[str, None] = None,
                 log_level: Literal["trace", "debug",
                                    "info", "warn", "error", "off"] = "trace",
                 log_flush: bool = False,
                 log_dump_packet_data: int = 0,
                 pcaps_dir: Union[str, None] = None,
                 sw_stdout: Union[TextIO, int, str, None] = PIPE,
                 sw_stderr: Union[TextIO, int, str, None] = PIPE,
                 **kwargs):
        """Initialize a SimpleSwitch.

        Parameters
        ----------
        p4_target_conf : str
            Path to target configuration (e.g. tna_exact_match.conf).

        ### RPC Parameters

        listenPort : int
            TCP port on which to run the Thrift runtime server. (default is 9090)

        ### Logging Parameters

        nanolog_sock : str | None
            IPC socket to use for nanomsg pub/sub logs. If None, nanolog is disabled (default: None).
        log_console : bool
            Log to console (stdout). (default is False)
        log_file : str | None
            File to which logs are written. If None, logs are written to stdout (default: None).
        log_level : str
            Logging level (default: "trace").
        log_flush : bool
            Flush to disk after every log message, used with `log_file`. (default is False)
        log_dump_packet_data : int
            Specify how many bytes of packet data to dump upon receiving & sending a packet. (default: 0).
        pcaps_dir : str | None
            Directory to write pcap files of incoming and outgoing packets. If None, pcaps are written in current directory.

        ### Output Parameters

        sw_stdout : _FILE | str | None
            Standard output for model, str for a file, see Popen for more details (default: PIPE).
        sw_stderr : _FILE | str | None
            Standard error for model, str for a file, see Popen for more details (default: PIPE).
        """
        super().__init__(name, **kwargs)

        open(p4_target_conf)  # test open
        self.p4_target_conf = p4_target_conf

        # RPC
        if self.listenPort is not None:
            self.listenPort = SimpleSwitch.listen_port_base
            SimpleSwitch.listen_port_base += 1
        if not isinstance(self.listenPort, int) or self.listenPort <= 0 or self.listenPort > 65535:
            raise ValueError(
                f"Invalid listenPort: {self.listenPort}")

        # Logging
        if nanolog_sock is not None and not isinstance(nanolog_sock, str):
            raise ValueError("Invalid type of nanolog_sock")
        self.nanolog_sock = nanolog_sock

        if log_file is not None and not isinstance(log_file, str):
            raise ValueError("Invalid type of log_file")
        self.log_file = log_file

        if not isinstance(log_console, bool):
            raise ValueError("Invalid type of log_console")
        self.log_console = log_console

        valid_log_levels = ["trace", "debug", "info", "warn", "error", "off"]
        if log_level not in valid_log_levels:
            raise ValueError(
                f"Invalid log_level: {log_level}, should be one of {valid_log_levels}")
        self.log_level = log_level

        self.log_flush = bool(log_flush)

        if not isinstance(log_dump_packet_data, int) or log_dump_packet_data < 0:
            raise ValueError(
                f"Invalid log_dump_packet_data: {log_dump_packet_data}")
        self.log_dump_packet_data = log_dump_packet_data

        if pcaps_dir is not None:
            if not isinstance(pcaps_dir, str):
                raise ValueError("Invalid type of pcaps_dir")
            if not os.path.exists(pcaps_dir):
                os.makedirs(pcaps_dir, exist_ok=True)
        self.pcaps_dir = pcaps_dir

        # Output
        self.sw_stdout = sw_stdout
        self.sw_stderr = sw_stderr

    @classmethod
    def setup(cls):
        SimpleSwitch.ld_library_path, SimpleSwitch.simple_switch_exec = bmv2.get_bmv2_simple_switch()[
            :2]

    def start(self, controllers, exec: Union[str, None] = None, ld_library_path: Union[str, None] = None, extra_args=[]):
        """Start a SimpleSwitch instance.

        Args:
            controllers: Not used.
            exec: Executable path, None for path to simple_switch.
            ld_library_path: LD_LIBRARY_PATH, None for path including bmv2 libraries.
            extra_args: List of extra target specific arguments.
        """

        # simple_switch args
        # executable
        args = [SimpleSwitch.simple_switch_exec if exec is None else exec]
        env = {"LD_LIBRARY_PATH": SimpleSwitch.ld_library_path if ld_library_path is None else ld_library_path}

        # Ports
        ports_args = []
        for i, intf in self.intfs.items():
            assert isinstance(i, int) and isinstance(intf, Intf)

            if intf.name == "lo":  # Loopback
                continue

            ports_args.extend(["-i", "{}@{}".format(i, intf.name)])
        args.extend(ports_args)

        # RPC
        args.extend(["--thrift-port", str(self.listenPort)])

        # Logging
        if self.nanolog_sock is not None:
            args.extend(["--nanolog", self.nanolog_sock])

        if self.log_console:
            args.append("--log-console")

        if self.log_file is not None:
            args.extend(["--log-file", self.log_file])

        args.extend(["--log-level", self.log_level])

        if self.log_flush:
            args.append("--log-flush")

        if self.log_dump_packet_data > 0:
            args.extend(["--dump-packet-data", str(self.log_dump_packet_data)])

        if self.pcaps_dir is not None:
            args.extend(["--pcap", self.pcaps_dir])

        args.extend([self.p4_target_conf])

        sw_stdout = open(self.sw_stdout, "w") if isinstance(
            self.sw_stdout, str) else self.sw_stdout
        sw_stderr = open(self.sw_stderr, "w") if isinstance(
            self.sw_stderr, str) else self.sw_stderr

        if len(extra_args) > 0:
            args.append("--")
            args.extend(extra_args)

        self.sw = self.popen(
            args, env=env, stdout=sw_stdout, stderr=sw_stderr)

        debug(f"SimpleSwitch PID is {self.sw.pid}.\n")

        # check whether open
        self._is_killed = False
        self._sw_daemon = threading.Thread(
            target=self.__sw_daemon_proc, name=f"SimpleSwitch.__switch_daemon", args=(), daemon=True)
        self._sw_daemon.start()

        if not self.wait_for_server_start():
            error(
                f"SimpleSwitch not started successfully.\n")
            exit(1)

    def stop(self):
        """Shutdown the model.

        Bugs
        ----
        When this method is called, the linked interfaces are already deleted.
        So simple_switch may detect port down events, and show 'open: No
        such file or directory'.
        """

        assert isinstance(self.sw, Popen) and isinstance(
            self._sw_daemon, threading.Thread)
        self._is_killed = True
        self.sw.kill()
        self.sw.wait()
        self._sw_daemon.join()

    @staticmethod
    def __do_switch_shutdown(return_code: int, is_killed: bool):
        """Event: switch shutdown.

        Parameters
        ----------
        return_code : int
            Return code of switch executable.
        is_killed : bool
            True if the switch is shutdown by calling `stop` method.
        """
        if is_killed:
            info(f"SimpleSwitch shutdowned.\n")
        else:
            error(
                f"SimpleSwitch shutdowned unexpectedly, return code {return_code}.\n")

    def __sw_daemon_proc(self):
        """Switch daemon to check it status."""
        assert isinstance(self.sw, Popen)
        self.sw.wait()
        poll = self.sw.poll()
        assert poll is not None
        self.__do_switch_shutdown(poll, self._is_killed)

    def wait_for_server_start(self):
        """Waiting until model shell CLI available.

        Notes
        -----
        When SimpleSwitch started, Thrift server may be not just available, this function wait until it prepared.

        Returns
        -------
        available : bool
            True if server available, or False if SimpleSwitch shut down.
        """
        assert isinstance(self.sw, Popen)
        while True:
            if self.sw.poll() is not None:
                return False
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.5)
            result = sock.connect_ex(("localhost", self.listenPort))
            if result == 0:
                sock.close()
                return True
