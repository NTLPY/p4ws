"""Run a Mininet instance."""

import argparse
import json
import os
import sys
from logging import _nameToLevel, basicConfig

from mininet.cli import CLI
from mininet.link import Intf, Link
from mininet.log import LEVELS, OUTPUT, setLogLevel, info
from mininet.moduledeps import pathCheck
from mininet.net import Mininet
from mininet.node import Host, Switch, Controller

from .mnhlp import JsonTopo, ParserError
from .utils import get_type, get_type_name


def make_loadmn_subparser(parser: argparse._SubParsersAction):
    """Make subparser of loadmn.

    Args:
        parser: An ArgumentParser.

    Returns:
        An ArgumentParser.
    """

    loadmn_parser = parser.add_parser("loadmn", help="Run a Mininet instance.")
    loadmn_parser.add_argument(
        "--topo-file", type=str, required=True, help="A file contains topology.")
    loadmn_parser.add_argument("--net-file",
                               type=argparse.FileType(),
                               required=False,
                               help="A file contains network configurations.")
    loadmn_parser.add_argument("--out-file",
                               type=argparse.FileType("w"),
                               required=False,
                               help="A json file to output.")
    loadmn_parser.add_argument("--shell-file",
                               type=argparse.FileType("w"),
                               required=False,
                               help="A file to write terminal entry.")
    loadmn_parser.add_argument("--mnexec",
                               default="mnexec",
                               type=str,
                               required=False,
                               help="Path to mininet executable.")
    loadmn_parser.add_argument("--log-level",
                               default="output",
                               type=str,
                               choices=LEVELS.keys(),
                               required=False,
                               help="Output log level.")
    return loadmn_parser


def config_intf(intf: Intf, conf):
    """Config an interface.

    Args:
        intf: A mininet.link.Intf to configured.
        conf: The configuration.
    """

    if isinstance(conf, list):
        # [("10.0.0.1", 16), ...]
        if (len(conf) > 0):
            intf.setIP(*conf.pop())
        # [("10.0.0.1", 16), "aa:bb:cc:dd:ee:ff"]
        if (len(conf) > 0):
            intf.setMAC(conf.pop())
        if conf:
            raise ParserError(f"Unsupported `Intf`: {conf}")
    elif isinstance(conf, dict):
        # { "ip" : ["...", 16], "name" : "...", "mac" : "..." }
        if "ip" in conf:
            intf.setIP(*conf.pop("ip"))
        if "mac" in conf:
            intf.setMAC(conf.pop("mac"))
        if "name" in conf:
            intf.rename(conf.pop("name"))
        if conf:
            raise ParserError(f"Unsupported `Intf`: {conf}")
    else:
        raise ParserError(f"Unsupported `Intf`: {conf}")


def main_loadmn(args: argparse.Namespace):
    """Main of loadmn executable."""

    # Set logging for mininet
    basicConfig(level=_nameToLevel[args.log_level.upper(
    )] if args.log_level != "output" else OUTPUT)
    setLogLevel(args.log_level)

    # Load topology
    info("*** Loading topology\n")
    topo_ext = os.path.splitext(args.topo_file)[1]
    if topo_ext == ".json":
        topo_file = open(args.topo_file, "r")
        topo = JsonTopo(topo_file)
    else:
        print(f"Unknwon type of topology file: {topo_ext}", file=sys.stderr)
        exit(1)

    # Load network
    info("*** Loading network\n")
    try:
        if (args.net_file):
            net_config = json.load(args.net_file)
        else:
            net_config = {}
    except Exception as e:
        print(f"Cannot load network file: {e}", file=sys.stderr)
        exit(1)

    # Default type
    def get_default_type(spec, name: str, base_type: type):
        if spec is not None:
            if not isinstance(spec, str):
                raise ParserError(
                    f"`{name}-type` should be str, not {get_type_name(spec)}")
            t = get_type(spec)
            assert t is not None
        else:
            t = base_type
        if not issubclass(t, base_type):
            raise ParserError(
                f"`{name}-type` should be derived of {get_type_name(base_type)}")
        return t

    host_type = get_default_type(net_config.get("host-type"), "host", Host)
    switch_type = get_default_type(
        net_config.get("switch-type"), "switch", Switch)
    controller_type = get_default_type(net_config.get(
        "controller-type"), "controller", Controller) if ("controller-type" not in net_config or net_config["controller-type"] is not None) else None
    link_type = get_default_type(net_config.get("link-type"), "link", Link)
    intf_type = get_default_type(net_config.get("intf-type"), "intf", Intf)

    net = Mininet(topo=topo,
                  switch=switch_type,
                  host=host_type,
                  controller=controller_type,
                  link=link_type,
                  intf=intf_type,
                  **net_config.get("net-config", {}))

    # Start network
    info("Starting network\n")
    net.start()

    # Init config
    # Init hosts
    info("*** Configuring hosts\n")
    if "hosts" in net_config:
        if not isinstance(net_config["hosts"], dict):
            raise ParserError("`hosts` should be object")

        for host_name, config in net_config["hosts"].items():
            assert isinstance(host_name, str), "Host name should be str"
            if not isinstance(config, dict):
                raise ParserError(
                    f"`Host` should be object, not {get_type_name(config)}")

            h = net.get(host_name)
            assert isinstance(h, Host)

            # Intfs
            if "intfs" in config:
                if isinstance(config["intfs"], list):
                    # [("10.0.0.1", 16), ...]
                    intf = h.defaultIntf()
                    if intf is None:
                        raise ValueError(
                            f"No default interface in {host_name}")
                    config_intf(intf, config["intfs"])
                elif isinstance(config["intfs"], dict):
                    # { "0" : ?, "1" : ? }
                    for port_, c in config["intfs"].items():
                        assert isinstance(port_, str)
                        try:
                            port = int(port_)
                        except ValueError:
                            raise ParserError(
                                f"Port number should be str of int, not {port_}")

                        if port not in h.intfs:
                            raise RuntimeError(
                                f"Port not found: {host_name}.{port}")
                        config_intf(h.intfs[port], c)
                else:
                    raise ParserError(
                        f"Unsupported `intfs` type: {get_type_name(config['intfs'])}")

            # Static ARPs
            if "arps" in config:
                if isinstance(config["arps"], list):
                    # [["10.0.0.1", "aa:bb:cc:dd:ee:ff"], [...], ...]
                    for item in config["arps"]:
                        if not isinstance(item, list) or len(item) == 2:
                            raise ParserError(
                                f"`arp` should be a pair of IP address and MAC address, not {item}")
                        ip, mac = item
                        h.setARP(ip, mac)
                elif isinstance(config["arps"], dict):
                    # { "10.0.0.1" : "aa:bb:cc:dd:ee:ff", ...}
                    for ip, mac in config["arps"].items():
                        h.setARP(ip, mac)
                else:
                    raise ParserError(
                        f"Unsupported `arps` type: {get_type_name(config['arps'])}")

            # Default route
            # 1 | "default"
            if "default-route" in config:
                if config["default-route"] == "default":
                    h.setDefaultRoute(h.defaultIntf())
                elif config["default-route"] in h.intfs:
                    h.setDefaultRoute(h.intfs[config["default-route"]])
                elif config["default-route"] in h.nameToIntf:
                    h.setDefaultRoute(h.nameToIntf[config["default-route"]])
                else:
                    raise ParserError(
                        f"Unknown `default-route`: {config['default-route']}")

            # Static Route
            if "routes" in config:
                if isinstance(config["routes"], list):
                    # [["10.0.0.1", 1], [...], ...]
                    for route in config["routes"]:
                        if not isinstance(route, list) or len(route) != 2 or not isinstance(route[0], str) or not isinstance(route[1], (int, str)):
                            raise ParserError(
                                f"`Host::Route` should be pair of str and int/str, not {route}")
                        ip, port = route
                        if isinstance(port, int):
                            h.setHostRoute(ip, h.intfs[port].name)
                        else:
                            h.setHostRoute(ip, port)
                elif isinstance(config["routes"], dict):
                    # { "10.0.0.1" : 1, ...}
                    for ip, port in config["routes"].items():
                        assert isinstance(ip, str), "IP address should be str"
                        if not isinstance(port, (int, str)):
                            raise ParserError(
                                f"`Host::Route::intf` should be int/str, not {get_type_name(port)}")
                        if isinstance(port, int):
                            h.setHostRoute(ip, h.intfs[port].name)
                        else:
                            h.setHostRoute(ip, port)
                else:
                    raise ParserError(
                        f"Unknown `routes`: {config['routes']}")

    # Init switches
    info("*** Configuring switches\n")
    if "switches" in net_config:
        if not isinstance(net_config["switches"], dict):
            raise ParserError(
                f"`switches` should be object, not {get_type_name(net_config['switches'])}")

        for switch_name, config in net_config["switches"].items():
            assert isinstance(switch_name, str), "Switch name should be str"
            if not isinstance(config, dict):
                raise ParserError(
                    f"`Switch` should be object, not {get_type_name(config)}")

            s = net.get(switch_name)
            assert isinstance(s, Switch)

            # Intfs
            if "intfs" in config:
                if isinstance(config["intfs"], list):
                    # [("10.0.0.1", 16), ...]
                    intf = s.defaultIntf()
                    if intf is None:
                        raise ValueError(
                            f"No default interface in {switch_name}")
                    config_intf(intf, config["intfs"])
                elif isinstance(config["intfs"], dict):
                    # { "0" : ?, "1" : ? }
                    for port_, c in config["intfs"].items():
                        assert isinstance(port_, str)
                        try:
                            port = int(port_)
                        except ValueError:
                            raise ParserError(
                                f"Port number should be str of int, not {port_}")

                        if port not in s.intfs:
                            raise RuntimeError(
                                f"Port not found: {switch_name}.{port}")
                        config_intf(s.intfs[port], c)
                else:
                    raise ParserError(
                        f"Unsupported `intfs` type: {get_type_name(config['intfs'])}")

    # Use static ARP
    if "populate-static-arp" in net_config and net_config["populate-static-arp"] is True:
        info("*** Setup static ARPs\n")
        net.staticArp()

    # Output
    if args.out_file:
        out = {
            "hosts":
            dict((host.name, {
                "intfs":
                dict((port, {
                    "name": intf.name,
                    "ip": [intf.ip, intf.prefixLen],
                    "mac": intf.mac
                }) for port, intf in host.intfs.items())
            }) for host in net.hosts),
            "switches":
            dict((switch.name, {
                "intfs":
                dict((port, {
                    "name": intf.name,
                    "ip": [intf.ip, intf.prefixLen],
                    "mac": intf.mac
                }) for port, intf in switch.intfs.items())
            }) for switch in net.switches)
        }
        json.dump(out, args.out_file)
        args.out_file.close()
        info("*** Configuration output writed\n")

    # Shell support
    node_names = [host.name for host in net.hosts
                  ] + [switch.name for switch in net.switches]
    if args.shell_file and args.mnexec:
        pathCheck("mnexec", moduleName='Mininet')

        shell = os.environ.get("SHELL", "bash")
        args.shell_file.writelines([
            f"#!{shell}\n", f"\n",
            f"# This file is created by mininet tool `loadmn` of P4 Workshop, do not modify it.\n",
            f"if [ $# -ne 1 ]; then\n",
            f"echo \"Usage: term [switch_name|host_name]\"\n",
            f"echo \"Available nodes: " + ", ".join(node_names) +
            ".\"\n", f"exit 1\n", f"fi\n", f"\n", f"case $1 in\n"
        ] + [f"{host.name}) PID={host.pid};;\n" for host in net.hosts] + [
            f"{switch.name}) PID={switch.pid};;\n" for switch in net.switches
        ] + [
            f"*)\n", f"    echo \"Usage: term [switch_name|host_name]\"\n",
            f"    echo \"Available nodes: " + ", ".join(node_names) +
            ".\"\n", f"    exit 1\n", f"esac\n", f"\n",
            f"sudo -E env PATH={os.environ.get('PATH', '')} mnexec -a ${{PID}} {shell}"
        ])
        os.chmod(args.shell_file.fileno(), 0o775)
        args.shell_file.close()
        info("*** Shell helper writed\n")

    # Start CLI
    CLI(net)
    net.stop()

    return 0
