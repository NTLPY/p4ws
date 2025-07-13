"""Mininet Node of TofinoModel.

This class represents a Mininet node specifically for the TofinoModel.
It inherits from `mininet.node.Switch` and is designed to integrate Tofino-based
simulations within a Mininet environment.

Typical usage example:

    net.addSwitch("foo", cls=TofinoModel)
"""


import json
import os
import socket
import tempfile
import threading
from enum import Enum
from subprocess import PIPE, Popen
from typing import List, TextIO, Tuple, Union

from mininet.link import Intf
from mininet.log import debug, error, info
from mininet.node import Switch

from p4ws.targets import bfsde


class ChipArch(Enum):
    """
    Chip Architecture of Tofino Series.
    """

    TOFINO = 0
    TOFINO2 = 1
    TOFINO2M = 2
    TOFINO3 = 3

    @staticmethod
    def to_chip_family(arch: "ChipArch"):
        """From chip architecture to chip family."""

        m = {
            ChipArch.TOFINO: ChipFamily.TofinoB0,
            ChipArch.TOFINO2: ChipFamily.JBayB0,
            ChipArch.TOFINO2M: ChipFamily.JBayB0,
            ChipArch.TOFINO3: ChipFamily.CloudBreak,
        }
        return m[arch]


class ChipFamily(Enum):
    """
    Chip Family of Tofino Series.
    """

    TofinoB0 = 2
    JBayB0 = 5
    CloudBreak = 6


class TofinoModel(Switch):
    """Mininet Node of TofinoModel.

    This class represents a Mininet node specifically for the TofinoModel.
    It inherits from `mininet.node.Switch` and is designed to integrate Tofino-based
    simulations within a Mininet environment.

    Typical usage example:

        net.addSwitch("foo", cls=TofinoModel)

    Attributes
    ----------
    p4_target_conf : str
        Path to target configuration.
    chip_family : ChipFamily
        Chip family.
    cli_port : int
        TCP port for model shell.
    cli_credentials : Tuple[str, str] | List[str] | None
        Username and password for model shell, None for no password.
    dru_sim_tcp_port_base : int
        TCP port base for dru_sim.
    time_disable : bool
        Do not automatically increment time.
    port_monitor : bool
        Monitor interfaces to detect port up/down events.
    dod_test_model : bool
        Set model to send every 10th DeflectOnDrop packet to Port0.
    log_dir : str
        Specify pkt-processing log file directory, None for no logging.
    json_log_enable : bool
        Enable JSON log stream.
    sw_stdout : TextIO | int | None
         Standard output for model, str for a file, see Popen for more details.
    sw_stderr : TextIO | int | None
        Standard error for model, str for a file, see Popen for more details.
    """

    num_of_instances = 0
    instances_started: list["TofinoModel"] = []
    num_of_instances_shutdowned = 0
    conf_file = None
    port_file = None

    cli_port = 8000

    sw = None
    _is_killed = False
    _sw_daemon = None

    sock = None

    def __init__(self, name,
                 p4_target_conf: str,
                 *,
                 chip_family: Union[ChipFamily, int] = ChipFamily.TofinoB0,
                 cli_port: int = 8000,
                 cli_credentials: Union[Tuple[str, str],
                                        List[str], None] = None,
                 dru_sim_tcp_port_base: int = 8001,
                 time_disable: bool = False,
                 port_monitor: bool = False,
                 dod_test_model: bool = False,
                 log_dir: Union[str, None] = None,
                 json_log_enable: bool = False,
                 sw_stdout: Union[TextIO, int, str, None] = PIPE,
                 sw_stderr: Union[TextIO, int, str, None] = PIPE,
                 **kwargs):
        """Initialize a TofinoModel.

        Parameters
        ----------
        p4_target_conf : str
            Path to target configuration (e.g. tna_exact_match.conf).
        chip_family : ChipFamily | int
            Chip family or its code (default: ChipFamily.TofinoB0).

        ### CLI Parameters

        cli_port : int
            TCP port for model shell (default: 8000).
        cli_credentials : (str, str) | [str, str] | None
            Username and password for model shell, None for no password (default: None).

        ### PCIe Parameters

        dru_sim_tcp_port_base : int
            TCP port base for dru_sim (default: 8001).

        ### Device Functional Parameters

        time_disable : bool
            Do not automatically increment time (default: False).
        port_monitor : bool
            Monitor interfaces to detect port up/down events (default: False).
        dod_test_model : bool
            Set model to send every 10th DeflectOnDrop packet to Port0 (default: False).

        ### Logging Parameters

        log_dir : str | None
            Specify pkt-processing log file directory, None for no logging (default: None).
        json_log_enable : bool
            Enable JSON log stream (default: False).

        ### Output Parameters

        sw_stdout : _FILE | str | None
            Standard output for model, str for a file, see Popen for more details (default: PIPE).
        sw_stderr : _FILE | str | None
            Standard error for model, str for a file, see Popen for more details (default: PIPE).
        """
        super().__init__(name, **kwargs)

        open(p4_target_conf)  # test open
        self.p4_target_conf = p4_target_conf

        if isinstance(chip_family, int):
            chip_family = ChipFamily(chip_family)
        elif isinstance(chip_family, ChipFamily):
            pass
        else:
            raise ValueError(f"Invalid chip_family: {chip_family}")
        self.chip_family = chip_family

        # CLI
        if not isinstance(cli_port, int) or cli_port <= 0 or cli_port > 65535:
            raise ValueError(
                f"Invalid cli_port: {cli_port}")
        self.cli_port = cli_port
        if cli_credentials is not None:
            if not isinstance(cli_credentials, (list, tuple))\
                    or not len(cli_credentials)\
                    or not isinstance(cli_credentials[0], str)\
                    or not isinstance(cli_credentials[1], str):
                raise ValueError("Invalid type of cli_credentials")
            if ":" in cli_credentials[0]:
                raise ValueError("Username should not contain ':'")
        self.cli_credentials = cli_credentials

        # PCIe
        if not isinstance(dru_sim_tcp_port_base, int) or dru_sim_tcp_port_base <= 0 or dru_sim_tcp_port_base > 65535:
            raise ValueError(
                f"Invalid dru_sim_tcp_port_base: {dru_sim_tcp_port_base}")
        self.dru_sim_tcp_port_base = dru_sim_tcp_port_base

        # Functional
        self.time_disable = bool(time_disable)
        self.port_monitor = bool(port_monitor)
        self.dod_test_model = bool(dod_test_model)

        # Logging
        if log_dir is not None and (not isinstance(log_dir, str) or not os.path.isdir(log_dir)):
            raise PermissionError("Not a directory")
        self.log_dir = log_dir
        self.json_log_enable = bool(json_log_enable)

        # Output
        self.sw_stdout = sw_stdout
        self.sw_stderr = sw_stderr

        TofinoModel.num_of_instances += 1

    @classmethod
    def setup(cls):
        TofinoModel.ld_library_path, TofinoModel.tofino_model_exec = bfsde.get_bfsde_tofino_model()[
            :2]

    def start(self, controllers):
        """Start a TofinoModel instance.

        Args:
            controllers: Not used.
        """

        TofinoModel.instances_started.append(self)
        if len(TofinoModel.instances_started) >= TofinoModel.num_of_instances:
            TofinoModel.__real_start(self)

    def stop(self):
        """Shutdown the model."""

        TofinoModel.num_of_instances_shutdowned += 1
        if TofinoModel.num_of_instances_shutdowned == TofinoModel.num_of_instances:
            TofinoModel.__real_shutdown()

    @staticmethod
    def __real_start(instance):
        # tofino-model args
        # executable
        args = [TofinoModel.tofino_model_exec]
        env = {"LD_LIBRARY_PATH": TofinoModel.ld_library_path}

        def check_only_one(property_name: str, fallback=None):
            prop = fallback
            for instance in TofinoModel.instances_started:
                prop_ = getattr(instance, property_name)
                if prop != fallback and prop_ != prop:
                    raise NotImplementedError(
                        f"Only one {property_name} is supported")

                prop = prop_
            return prop

        conf_out = {"chip_list": [], "p4_devices": [], "switch_options": []}
        for i, instance in enumerate(TofinoModel.instances_started):
            conf = json.load(open(instance.p4_target_conf))

            if len(conf["chip_list"]) != 1:
                raise ValueError(
                    f"Only one chip is supported, but got {len(conf['chip_list'])} chips in {instance.p4_target_conf}")
            chip = conf["chip_list"][0]
            chip["instance"] = i
            conf_out["chip_list"].append(chip)

            if len(conf["p4_devices"]) != 1:
                raise ValueError(
                    f"Only one P4 device is supported, but got {len(conf['p4_devices'])} devices in {instance.p4_target_conf}")
            p4_device = conf["p4_devices"][0]
            p4_device["device-id"] = i
            conf_out["p4_devices"].append(p4_device)

            if len(conf["switch_options"]) != 1:
                raise ValueError(
                    f"Only one switch options is supported, but got {len(conf['p4_devices'])} devices in {instance.p4_target_conf}")
            switch_options = conf["switch_options"][0]
            switch_options["device-id"] = i
            conf_out["switch_options"].append(switch_options)
        TofinoModel.conf_file = tempfile.NamedTemporaryFile(
            "w", prefix="p4ws.mnhlp.nodes.TofinoModel.conf_file-", suffix=".json")
        json.dump(conf_out, TofinoModel.conf_file)
        TofinoModel.conf_file.flush()
        args.extend(["--p4-target-config", TofinoModel.conf_file.name])
        debug(f"conf_out {TofinoModel.conf_file.name}: ", conf_out)

        # Number of devices
        num_of_devices = TofinoModel.num_of_instances
        args.extend(["--num-of-chips", str(num_of_devices)])

        # Ports
        ports_out = {"PortToVeth": []}
        for i, instance in enumerate(TofinoModel.instances_started):
            base = i * 512

            for i, intf in instance.intfs.items():
                assert isinstance(i, int) and isinstance(intf, Intf)

                if intf.name == "lo":  # Loopback
                    continue

                dev_port = base + i - 1
                veth1_id = base + dev_port * 2
                veth2_id = veth1_id + 1

                intf.rename(f"veth{veth1_id}")
                ports_out["PortToVeth"].append({"device_port": dev_port,
                                                "veth1": veth1_id,
                                                "veth2": veth2_id})
        TofinoModel.port_file = tempfile.NamedTemporaryFile(
            "w", prefix="p4ws.mnhlp.nodes.TofinoModel.port_file-", suffix=".json")
        json.dump(ports_out, TofinoModel.port_file)
        TofinoModel.port_file.flush()
        args.extend(["-f", TofinoModel.port_file.name])
        debug(f"ports_out {TofinoModel.port_file.name}: ", ports_out)

        # CLI
        TofinoModel.cli_port = check_only_one("cli_port", 8000)
        assert isinstance(TofinoModel.cli_port, int)
        args.extend(["--cli-port", str(TofinoModel.cli_port)])
        cli_credentials = check_only_one("cli_credentials")
        if cli_credentials:
            cli_credentials_file = tempfile.NamedTemporaryFile(
                "w", prefix="cli-credentials-", suffix=".json")
            username, password = cli_credentials
            if ":" in username:
                raise ValueError(f"Invalid username: {username}")
            cli_credentials_file.write(f"{username}:{password}")
            cli_credentials_file.flush()
            args.extend(["--cli-credentials", cli_credentials_file.name])

        # PCIe
        dru_sim_tcp_port_base = check_only_one("dru_sim_tcp_port_base", 8001)
        args.extend(["-t", str(dru_sim_tcp_port_base)])

        # Functional
        time_disable = check_only_one("time_disable", False)
        if time_disable:
            args.append("--time-disable")
        port_monitor = check_only_one("port_monitor", False)
        if port_monitor:
            args.append("--port-monitor")
        dod_test_model = check_only_one("dod_test_model", False)
        if dod_test_model:
            args.append("--dod-test-mode")

        # Logging
        log_dir = check_only_one("log_dir")
        if log_dir is not None:
            args.extend(["--log-dir", log_dir])
            json_log_enable = check_only_one("json_log_enable", False)
            if json_log_enable:
                args.extend(["--json-logs-enable"])
        else:
            args.extend(["--logs-disable"])

        sw_stdout, sw_stderr = check_only_one(
            "sw_stdout", PIPE), check_only_one("sw_stderr", PIPE)
        sw_stdout = open(sw_stdout, "w") if isinstance(
            sw_stdout, str) else sw_stdout
        sw_stderr = open(sw_stderr, "w") if isinstance(
            sw_stderr, str) else sw_stderr

        TofinoModel.sw = instance.popen(
            args, env=env, stdout=sw_stdout, stderr=sw_stderr)

        debug(f"TofinoModel PID is {TofinoModel.sw.pid}.\n")

        # check whether open
        TofinoModel._is_killed = False
        TofinoModel._sw_daemon = threading.Thread(
            target=TofinoModel.__sw_daemon_proc, name=f"TofinoModel.__switch_daemon", args=(), daemon=True)
        TofinoModel._sw_daemon.start()

        if not TofinoModel.wait_for_server_start():
            error(
                f"TofinoModel not started successfully.\n")
            exit(1)

    @staticmethod
    def __real_shutdown():
        assert isinstance(TofinoModel.sw, Popen) and isinstance(
            TofinoModel._sw_daemon, threading.Thread)
        TofinoModel._is_killed = True
        TofinoModel.sw.kill()
        TofinoModel.sw.wait()
        TofinoModel._sw_daemon.join()

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
            info(f"TofinoModel shutdowned.\n")
        else:
            error(
                f"TofinoModel shutdowned unexpectedly, return code {return_code}.\n")

    @staticmethod
    def __sw_daemon_proc():
        """Switch daemon to check it status."""
        assert isinstance(TofinoModel.sw, Popen)
        TofinoModel.sw.wait()
        poll = TofinoModel.sw.poll()
        assert poll is not None
        TofinoModel.__do_switch_shutdown(
            poll, TofinoModel._is_killed)

    @staticmethod
    def wait_for_server_start():
        """Waiting until model shell CLI available.

        Notes
        -----
        When TofinoModel started, following components will be initialized:
        - dru_sim TCP port
        - port mapping file
        - ports initialztions
        - CLI TCP port
        This function wait until CLI TCP port available.

        Returns
        -------
        available : bool
            True if CLI available, or False if model shutdown.
        """
        assert isinstance(TofinoModel.sw, Popen)
        while True:
            if TofinoModel.sw.poll() is not None:
                return False
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.5)
            result = sock.connect_ex(("localhost", TofinoModel.cli_port))
            if result == 0:
                TofinoModel.sock = sock
                return True
