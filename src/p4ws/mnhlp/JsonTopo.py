"""Read topology from a json file.

Typical usage example:

    with open("topo.json") as f:
        topo = JsonTopo(f)
"""

import json
from typing import TextIO

from mininet.node import Host, OVSSwitch
from mininet.topo import Topo

from p4ws.utils import get_type, get_type_name

from .error import ParserError


class JsonTopo(Topo):
    """Json topology.

    Read topology from a json file.
    Typical usage example:

        with open("topo.json") as f:
            topo = JsonTopo(f)
    """

    def __init__(self, fp: TextIO, **kwargs):
        """Read topology from a json file.

        Args:
            fp: File object to be read.

        Kwargs:
            **kwargs: Keyword arguments for construct class Topo.

        Returns:
            A JsonTopo.

        Raises:
            json.decoder.JSONDecodeError: Format of json is incorrect.
            ParserError: Format of topology is incorrect.
            ModuleNotFoundError: Module of specified class type (`cls`) not found.
            AttributeError: Specified class type (`cls`) not found.
            ValueError: Specified class type (`cls`) is not name of a type.
        """

        # Init topology and default options
        Topo.__init__(self, **kwargs)

        conf = json.load(fp)

        if not isinstance(conf, dict):
            raise ParserError("Top-level should be object")

        # Init classes
        classes = {
            "host": {
                "cls": Host
            },
            "switch": {
                "cls": OVSSwitch
            }
        }

        if "classes" in conf:
            if not isinstance(conf["classes"], dict):
                raise ParserError(
                    f"`classes` should be object, not {get_type_name(conf['classes'])}")

            for name, spec in conf["classes"].items():
                assert isinstance(name, str), "Class name should be str"
                assert (name in {"host", "switch", "link"}
                        ) or (name not in classes), f"Class `{name}` exists"
                if not isinstance(spec, dict):
                    raise ParserError(
                        f"`class` should be object, not {get_type_name(spec)}")

                style = {}

                # Inherit from parent
                if "parent" in spec:
                    if not isinstance(spec["parent"], str):
                        raise ParserError(
                            f"`class::parent` should be str, not {get_type_name(spec['parent'])}")

                    pn = spec.pop("parent")
                    if pn not in classes:
                        raise ParserError(f"Class `{pn}` undefined")

                    style = classes[pn].copy()

                # Get real type
                if "cls" in spec:
                    spec["cls"] = get_type(spec["cls"])

                style.update(spec)

                classes[name] = style

        def get_style_from_spec(spec: dict, t: str):
            if "class" in spec:
                cn = spec.pop("class")
                if not isinstance(cn, str):
                    raise ParserError(
                        f"Class name should be str, not {get_type_name(cn)}")
                if cn not in classes:
                    raise ParserError(f"Class `{cn}` not exists")

                style = classes[cn].copy()
            else:
                style = classes.get(t, {}).copy()

            # Get real type
            if "cls" in spec:
                spec["cls"] = get_type(spec["cls"])

            style.update(spec)
            return style

        # init hosts
        if "hosts" in conf:
            hosts = conf["hosts"]
            if isinstance(hosts, dict):
                # { "h1" : { opts, ...}, "h2" : { opts, ...}, ...}
                for h, spec in hosts.items():
                    assert isinstance(h, str), "Host name should be str"
                    if not isinstance(spec, dict):
                        raise ParserError(
                            f"`host` should be object, not {get_type_name(spec)}")

                    style = get_style_from_spec(spec, "hosts")
                    self.addHost(h, **style)
            elif (isinstance(hosts, list)):
                # ["h1", "h2", ...]
                style = classes.get("host", {}).copy()
                for h in hosts:
                    if not isinstance(h, str):
                        raise ParserError(
                            f"Host name should be str, not {get_type_name(h)}")
                    self.addHost(h, **style)
            else:
                raise ParserError(
                    f"Unsupported `hosts` type: {get_type_name(hosts)}")

        # Init switches
        if "switches" in conf:
            switches = conf["switches"]
            if isinstance(switches, dict):
                # { "s1" : { opts, ...}, "s2" : { opts, ...}, ...}
                for s, spec in switches.items():
                    assert isinstance(s, str), "Switch name should be str"
                    if not isinstance(spec, dict):
                        raise ParserError("`switch` should be object")

                    style = get_style_from_spec(spec, "switch")
                    self.addSwitch(s, **style)
            elif (isinstance(switches, list)):
                # ["s1", "s2", ...]
                style = classes.get("switch", {}).copy()
                for s in switches:
                    if not isinstance(s, str):
                        raise ParserError(
                            f"Switch name should be str, not {get_type_name(s)}")
                    self.addSwitch(s, **style)
            else:
                raise ParserError(
                    f"Unsupported `switches` type: {get_type_name(switches)}")

        # Init links
        if "links" in conf:
            links = conf["links"]
            if not isinstance(links, list):
                raise ParserError(
                    f"`links` should be array, not {get_type_name(links)}")

            for l in links:
                if isinstance(l, list):
                    if len(l) == 2:
                        # [node1, nodes]
                        node1, node2 = l
                        port1, port2, spec = None, None, {}
                    elif len(l) == 3:
                        # [node1, nodes, { opts, ... }]
                        node1, node2, spec = l
                        port1, port2 = None, None
                    elif len(l) == 4:
                        # [node1, node2, port1, port2]
                        node1, node2, port1, port2 = l
                        spec = {}
                    elif len(l) == 5:
                        # [node1, node2, port1, port2, { opts, ... }]
                        node1, node2, port1, port2, spec = l
                    else:
                        raise ParserError("`link` too long")

                    if not isinstance(node1, str):
                        raise ParserError(
                            f"`link::node1` should be str, not {get_type_name(node1)}")
                    if not isinstance(node2, str):
                        raise ParserError(
                            f"`link::node2` should be str, not {get_type_name(node2)}")
                    if not isinstance(spec, dict):
                        raise ParserError("`link::spec` should be object")

                    # port not in spec has higher priority
                    port1_ = spec.pop("port1", port1)
                    if port1 is None:
                        port1 = port1_
                    port2_ = spec.pop("port2", port2)
                    if port2 is None:
                        port2 = port2_

                    if port1 is not None and not isinstance(port1, int):
                        raise ParserError(
                            f"`link::port1` should be int, not {get_type_name(port1)}")
                    if port2 is not None and not isinstance(port2, int):
                        raise ParserError(
                            f"`link::port2` should be int, not {get_type_name(port2)}")

                    style = get_style_from_spec(spec, "link")
                    self.addLink(node1, node2, port1, port2, **style)

                elif isinstance(l, dict):
                    if "node1" not in l or "node2" not in l:
                        raise ParserError(
                            "Both side of link should not be ignored")
                    node1, node2, port1, port2 = l.pop("node1"), l.pop(
                        "node2"), l.pop("port1", None), l.pop("port2", None)
                    spec = l

                    if not isinstance(node1, str):
                        raise ParserError(
                            f"`link::node1` should be str, not {get_type_name(node1)}")
                    if not isinstance(node2, str):
                        raise ParserError(
                            f"`link::node2` should be str, not {get_type_name(node2)}")
                    if port1 is not None and not isinstance(port1, int):
                        raise ParserError(
                            f"`link::port1` should be int, not {get_type_name(port1)}")
                    if port2 is not None and not isinstance(port2, int):
                        raise ParserError(
                            f"`link::port2` should be int, not {get_type_name(port2)}")

                    style = get_style_from_spec(spec, "link")
                    self.addLink(node1, node2, port1, port2, **style)

                else:
                    raise ParserError(
                        f"Unsupported `link` type: {get_type_name(l)}")
