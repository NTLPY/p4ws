"""Mininet Node of SimpleSwitchGrpc.

This class represents a Mininet node specifically for the SimpleSwitchGrpc.
It inherits from `mininet.node.SimpleSwitch` and is designed to integrate Bmv2-based
simulations within a Mininet environment.

Typical usage example:

    net.addSwitch("foo", cls=SimpleSwitchGrpc)
"""

import os
import socket
from subprocess import Popen
from typing import Union

from p4ws.mnhlp.nodes.SimpleSwitch import SimpleSwitch
from p4ws.targets import bmv2


class SimpleSwitchGrpc(SimpleSwitch):
    """Mininet Node of SimpleSwitchGrpc.

    This class represents a Mininet node specifically for the SimpleSwitchGrpc.
    It inherits from `mininet.node.Switch` and is designed to integrate Bmv2-based
    simulations within a Mininet environment.

    Typical usage example:

        net.addSwitch("foo", cls=SimpleSwitchGrpc)

    Attributes
    ----------
    grpc_server_addr : tuple[str, int]
        Address (IP, port) on which the gRPC server listens.
    grpc_server_ssl : bool
        Whether to use SSL/TLS for gRPC server connection.
    grpc_server_cacert : str | None
        Path to pem file holding CA certificate to verify peer against.
    grpc_server_cert : str | None
        Path to pem file holding server certificate.
    grpc_server_key : str | None
        Path to pem file holding server private key.
    grpc_server_with_client_auth : bool
        Require client to have a valid certificate for mutual authentication.
    """

    grpc_listen_port_base = 9559

    def __init__(self, name, *,
                 grpc_server_port: Union[int, None] = None,
                 grpc_server_ssl: bool = False,
                 grpc_server_cacert: Union[str, None] = None,
                 grpc_server_cert: Union[str, None] = None,
                 grpc_server_key: Union[str, None] = None,
                 grpc_server_with_client_auth: bool = False,
                 **kwargs):
        """Initialize a SimpleSwitchGrpc.

        Parameters
        ----------
        ### RPC Parameters

        grpc_server_port : int | None
            TCP port on which to run the gRPC server. If None, an available port
            starting from 9559 will be assigned automatically.
        grpc_server_ssl : bool
            Whether to use SSL/TLS for gRPC server connection.
        grpc_server_cacert : str | None
            Path to pem file holding CA certificate to verify peer against.
        grpc_server_cert : str | None
            Path to pem file holding server certificate.
        grpc_server_key : str | None
            Path to pem file holding server private key.
        grpc_server_with_client_auth : bool
            Require client to have a valid certificate for mutual authentication.

        ### Other Parameters

        See `SimpleSwitch.__init__` for other parameters.
        """
        super().__init__(name, **kwargs)

        # RPC
        if grpc_server_port is None:
            self.grpc_server_addr = ("0.0.0.0",
                                     SimpleSwitchGrpc.grpc_listen_port_base)
            SimpleSwitchGrpc.grpc_listen_port_base += 1
        elif not isinstance(grpc_server_port, int) or not (0 < grpc_server_port < 65536):
            raise ValueError(
                f"Invalid gRPC server port number: {grpc_server_port}")
        else:
            self.grpc_server_addr = ("0.0.0.0", grpc_server_port)

        self.grpc_server_ssl = grpc_server_ssl
        if grpc_server_cacert is not None and not os.path.isfile(grpc_server_cacert):
            raise ValueError(
                f"gRPC server CA certificate file not found: {grpc_server_cacert}")
        self.grpc_server_cacert = grpc_server_cacert

        if grpc_server_cert is not None and not os.path.isfile(grpc_server_cert):
            raise ValueError(
                f"gRPC server certificate file not found: {grpc_server_cert}")
        self.grpc_server_cert = grpc_server_cert

        if grpc_server_key is not None and not os.path.isfile(grpc_server_key):
            raise ValueError(
                f"gRPC server key file not found: {grpc_server_key}")
        self.grpc_server_key = grpc_server_key

        self.grpc_server_with_client_auth = grpc_server_with_client_auth

    @classmethod
    def setup(cls):
        SimpleSwitchGrpc.ld_library_path, SimpleSwitchGrpc.simple_switch_grpc_exec = bmv2.get_bmv2_simple_switch_grpc()[
            :2]

    def start(self, controllers):
        """Start a SimpleSwitchGrpc instance.

        Args:
            controllers: Not used.
        """

        extra_args = []
        extra_args.extend(
            ["--grpc-server-addr", "{}:{}".format(*self.grpc_server_addr)])
        if self.grpc_server_ssl:
            extra_args.append("--grpc-server-ssl")
        if self.grpc_server_cacert is not None:
            extra_args.extend(
                ["--grpc-server-cacert", self.grpc_server_cacert])
        if self.grpc_server_cert is not None:
            extra_args.extend(["--grpc-server-cert", self.grpc_server_cert])
        if self.grpc_server_key is not None:
            extra_args.extend(["--grpc-server-key", self.grpc_server_key])
        if self.grpc_server_with_client_auth:
            extra_args.append("--grpc-server-with-client-auth")

        super().start(controllers, SimpleSwitchGrpc.simple_switch_grpc_exec,
                      SimpleSwitchGrpc.ld_library_path, extra_args)

    def wait_for_server_start(self):
        """Waiting until model shell CLI available.

        Notes
        -----
        When SimpleSwitchGrpc started, gRPC server may be not just available, this function wait until it prepared.

        Returns
        -------
        available : bool
            True if server available, or False if SimpleSwitchGrpc shut down.
        """
        assert isinstance(self.sw, Popen)
        while True:
            if self.sw.poll() is not None:
                return False
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.5)
            result = sock.connect_ex(self.grpc_server_addr)
            if result == 0:
                sock.close()
                return True
