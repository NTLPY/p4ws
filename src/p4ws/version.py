"""Version."""

import sys

_found_version = False

# The package is configured
try:
    from ._version import __version__
    _found_version = True
except ImportError:
    print("p4ws is not configured. Please run 'mkdir -p build && cd build && cmake ..' to configure it.", file=sys.stderr)

# If the version is not set, try to get it from setuptools_scm
if not _found_version:
    try:
        from setuptools_scm import get_version
        __version__ = get_version(root="../..", relative_to=__file__)
        _found_version = True
    except ImportError:
        print("setuptools_scm is not installed. We cannot determine version of p4ws.", file=sys.stderr)
    except LookupError:
        print("setuptools-scm was unable to detect version of p4ws. Maybe you are not under a development environment.", file=sys.stderr)
