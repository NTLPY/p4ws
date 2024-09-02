"""P4 Workshop."""

import pkg_resources

try:
    __version__ = pkg_resources.get_distribution('p4ws').version
except pkg_resources.DistributionNotFound:
    __version__ = "unknown"
