"""
Example usage of pyssas-deploy library.

This example demonstrates how to deploy a .bim file to an SSAS server
using both the Python API and command-line interface.
"""

from pyssas_deploy import deploy_bim
from pyssas_deploy.deploy import SSASDeploymentError

# Example 1: Basic deployment using Python API
def deploy_basic_example():
    """Deploy a .bim file with basic settings."""
    try:
        result = deploy_bim(
            bim_path="examples/sample_model.bim",
            server="localhost",
            database_name="SampleDatabase"
        )
        print(f"✓ Deployment successful!")
        print(f"  Database: {result['database']}")
        print(f"  Server: {result['server']}")
    except SSASDeploymentError as e:
        print(f"✗ Deployment failed: {e}")


# Example 2: Deployment with authentication
def deploy_with_auth_example():
    """Deploy a .bim file with authentication."""
    try:
        result = deploy_bim(
            bim_path="examples/sample_model.bim",
            server="myserver.database.windows.net",
            database_name="SampleDatabase",
            username="admin",
            password="secure_password",
            use_https=True
        )
        print(f"✓ Deployment successful!")
        print(f"  Database: {result['database']}")
        print(f"  Server: {result['server']}")
    except SSASDeploymentError as e:
        print(f"✗ Deployment failed: {e}")


# Example 3: Azure Analysis Services deployment
def deploy_to_azure_example():
    """Deploy to Azure Analysis Services."""
    try:
        result = deploy_bim(
            bim_path="examples/sample_model.bim",
            server="asazure://region.asazure.windows.net/myserver",
            database_name="SampleDatabase",
            username="user@domain.com",
            password="password",
            port=443,
            use_https=True
        )
        print(f"✓ Deployment successful!")
    except SSASDeploymentError as e:
        print(f"✗ Deployment failed: {e}")


if __name__ == "__main__":
    print("pyssas-deploy Usage Examples")
    print("=" * 50)
    
    print("\n1. Basic Deployment (will fail without server):")
    print("   from pyssas_deploy import deploy_bim")
    print("   result = deploy_bim('model.bim', 'server', 'database')")
    
    print("\n2. Command-line usage:")
    print("   pyssas-deploy deploy model.bim server database")
    
    print("\n3. With authentication:")
    print("   pyssas-deploy deploy model.bim server db -u user -p pass")
    
    print("\n4. Azure Analysis Services:")
    print("   pyssas-deploy deploy model.bim asazure://... db --https")
    
    print("\nFor more information, run: pyssas-deploy --help")
