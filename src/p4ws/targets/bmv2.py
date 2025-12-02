"""Utils for BMv2."""

import os
from re import match
from shutil import which
from subprocess import CalledProcessError, check_output

BMV2_INSTALL = ""


def get_bmv2_install(*suffix: str):
    """Get path to install path of BMv2.

    Check envs below to check install path to BMv2:
    1. `BMV2_INSTALL`

    Returns:
        A str of install path to BMv2.

    Raises:
        FileNotFoundError: Install path of BMv2 not found.
    """

    global BMV2_INSTALL
    if BMV2_INSTALL == "":
        BMV2_INSTALL = os.environ.get("BMV2_INSTALL", "")
    if BMV2_INSTALL == "":
        raise FileNotFoundError("Install path of BMv2 not found")
    return os.path.join(BMV2_INSTALL, *suffix)


def get_bmv2_model(name: str):
    """Get BMv2 model.

    Get `LD_LIBRARY_PATH`, path to, version and commit of model.

    `CAP_NET_RAW` privilege is required.

    Args:
        name: Name of BMv2 model.

    Returns:
        A tuple of str include `LD_LIBRARY_PATH`, path to, version and commit of model.

    Raises:
        CalledProcessError: Maybe library not found or priviledge required.
        UnicodeDecodeError: Output of model cannot be decoded as utf-8.
        FileNotFoundError: Install path of Barefoot SDE or model not found.
        PermissionError: Execution priviledge required.
        OSError: Maybe file of model is corrupted and cannot be executed.
        RuntimeError: Output of model is unexpected.
    """

    ld_path = ""
    model = which(name)

    if model is None:
        model = which(name, path=get_bmv2_install("bin"))

    if model is None:
        raise FileNotFoundError(f"{name} not found in PATH")

    try:
        out = check_output([model, "--version"],
                           env={"LD_LIBRARY_PATH": ld_path})
        out_str = out.decode("utf-8")
    except CalledProcessError as e:
        # Library / sudo
        raise e
    except UnicodeDecodeError as e:
        # Unexpected output
        raise e
    except FileNotFoundError as e:
        raise e
    except PermissionError as e:
        raise e
    except OSError as e:
        # Unexpected file
        raise e

    for line in out_str.split('\n'):
        m = match(
            r"([0-9]+\.[0-9]+\.[0-9]+)-([0-9a-z]{8})", line)
        if m is not None:
            ver, commit = m.groups()
            return ld_path, model, ver, commit

    # Unexpected output
    raise RuntimeError(f"Unexpected output of {name}: {out_str}")


def get_bmv2_simple_switch():
    """Get `simple_switch`.

    Get `LD_LIBRARY_PATH`, path to, version and commit of `simple_switch`.

    `CAP_NET_RAW` privilege is required.

    Returns:
        A tuple of str include `LD_LIBRARY_PATH`, path to, version and commit of `simple_switch`.

    Raises:
        See get_bmv2_model for possible exceptions.
    """
    return get_bmv2_model("simple_switch")


def get_bmv2_psa_switch():
    """Get `psa_switch`.

    Get `LD_LIBRARY_PATH`, path to, version and commit of `psa_switch`.

    `CAP_NET_RAW` privilege is required.

    Returns:
        A tuple of str include `LD_LIBRARY_PATH`, path to, version and commit of `psa_switch`.

    Raises:
        See get_bmv2_model for possible exceptions.
    """
    return get_bmv2_model("psa_switch")


def get_bmv2_pna_nic():
    """Get `pna_nic`.

    Get `LD_LIBRARY_PATH`, path to, version and commit of `pna_nic`.

    `CAP_NET_RAW` privilege is required.

    Returns:
        A tuple of str include `LD_LIBRARY_PATH`, path to, version and commit of `pna_nic`.

    Raises:
        See get_bmv2_model for possible exceptions.
    """
    return get_bmv2_model("pna_nic")
