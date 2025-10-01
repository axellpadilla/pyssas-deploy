"""
pyssas-deploy: Platform-agnostic Python tool for deploying .bim files to SSAS servers.
"""

__version__ = "0.1.0"

from .deploy import deploy_bim

__all__ = ["deploy_bim"]
