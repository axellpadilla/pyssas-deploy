"""
Core deployment functionality for deploying .bim files to SSAS servers.
"""

import json
import logging
from typing import Dict, Optional
import requests
from requests.auth import HTTPBasicAuth

logger = logging.getLogger(__name__)


class SSASDeploymentError(Exception):
    """Custom exception for SSAS deployment errors."""
    pass


def load_bim_file(bim_path: str) -> Dict:
    """
    Load and parse a .bim file.
    
    Args:
        bim_path: Path to the .bim file
        
    Returns:
        Dictionary containing the parsed .bim model
        
    Raises:
        SSASDeploymentError: If file cannot be loaded or parsed
    """
    try:
        with open(bim_path, 'r', encoding='utf-8') as f:
            bim_content = json.load(f)
        logger.info(f"Successfully loaded .bim file from {bim_path}")
        return bim_content
    except FileNotFoundError:
        raise SSASDeploymentError(f"BIM file not found: {bim_path}")
    except json.JSONDecodeError as e:
        raise SSASDeploymentError(f"Invalid BIM file format: {e}")
    except Exception as e:
        raise SSASDeploymentError(f"Error loading BIM file: {e}")


def create_tmsl_script(bim_data: Dict, database_name: str, overwrite: bool = True) -> Dict:
    """
    Create a TMSL (Tabular Model Scripting Language) script for deployment.
    
    Args:
        bim_data: Parsed .bim file data
        database_name: Name for the database
        overwrite: Whether to overwrite existing database
        
    Returns:
        TMSL script as a dictionary
    """
    # TMSL script to create or replace the database
    tmsl_script = {
        "createOrReplace": {
            "object": {
                "database": database_name
            },
            "database": bim_data
        }
    }
    
    logger.debug(f"Created TMSL script for database: {database_name}")
    return tmsl_script


def deploy_bim(
    bim_path: str,
    server: str,
    database_name: str,
    username: Optional[str] = None,
    password: Optional[str] = None,
    overwrite: bool = True,
    port: int = 2383,
    use_https: bool = False
) -> Dict:
    """
    Deploy a .bim file to an SSAS server.
    
    Args:
        bim_path: Path to the .bim file
        server: SSAS server address
        database_name: Name for the deployed database
        username: Optional username for authentication
        password: Optional password for authentication
        overwrite: Whether to overwrite existing database (default: True)
        port: Server port (default: 2383 for Azure AS)
        use_https: Whether to use HTTPS (default: False)
        
    Returns:
        Dictionary containing deployment result
        
    Raises:
        SSASDeploymentError: If deployment fails
    """
    logger.info(f"Starting deployment of {bim_path} to {server}/{database_name}")
    
    # Load the .bim file
    bim_data = load_bim_file(bim_path)
    
    # Create TMSL script
    tmsl_script = create_tmsl_script(bim_data, database_name, overwrite)
    
    # Construct the XMLA endpoint URL
    protocol = "https" if use_https else "http"
    url = f"{protocol}://{server}:{port}/xmla"
    
    logger.info(f"Deploying to endpoint: {url}")
    
    # Prepare authentication
    auth = None
    if username and password:
        auth = HTTPBasicAuth(username, password)
    
    # Prepare headers
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    try:
        # Execute TMSL script via REST API
        response = requests.post(
            url,
            json=tmsl_script,
            headers=headers,
            auth=auth,
            timeout=300  # 5 minute timeout for large models
        )
        
        response.raise_for_status()
        
        result = response.json()
        logger.info(f"Deployment successful for database: {database_name}")
        
        return {
            "status": "success",
            "database": database_name,
            "server": server,
            "result": result
        }
        
    except requests.exceptions.RequestException as e:
        error_msg = f"Deployment failed: {e}"
        logger.error(error_msg)
        raise SSASDeploymentError(error_msg)
    except Exception as e:
        error_msg = f"Unexpected error during deployment: {e}"
        logger.error(error_msg)
        raise SSASDeploymentError(error_msg)
