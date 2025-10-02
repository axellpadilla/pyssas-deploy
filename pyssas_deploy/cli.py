#!/usr/bin/env python
"""
Command-line interface for pyssas-deploy.
"""

import argparse
import logging
import sys
from pyssas_deploy import deploy_bim
from pyssas_deploy.deploy import SSASDeploymentError


def setup_logging(verbose: bool = False):
    """Configure logging."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )


def main():
    """Main entry point for CLI."""
    parser = argparse.ArgumentParser(
        description='Deploy .bim files to SSAS servers',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Deploy with default settings
  pyssas-deploy deploy model.bim myserver.database.windows.net MyDatabase
  
  # Deploy with authentication
  pyssas-deploy deploy model.bim myserver MyDatabase -u admin -p password
  
  # Deploy to Azure Analysis Services with HTTPS
  pyssas-deploy deploy model.bim asazure://region.asazure.windows.net/myserver MyDatabase --https
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Deploy command
    deploy_parser = subparsers.add_parser('deploy', help='Deploy a .bim file to SSAS server')
    deploy_parser.add_argument('bim_file', help='Path to the .bim file')
    deploy_parser.add_argument('server', help='SSAS server address')
    deploy_parser.add_argument('database', help='Target database name')
    deploy_parser.add_argument('-u', '--username', help='Username for authentication')
    deploy_parser.add_argument('-p', '--password', help='Password for authentication')
    deploy_parser.add_argument('--port', type=int, default=2383, help='Server port (default: 2383)')
    deploy_parser.add_argument('--https', action='store_true', help='Use HTTPS')
    deploy_parser.add_argument('--no-overwrite', action='store_true', 
                              help='Fail if database already exists (default: overwrite)')
    deploy_parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    if args.command == 'deploy':
        setup_logging(args.verbose)
        
        try:
            result = deploy_bim(
                bim_path=args.bim_file,
                server=args.server,
                database_name=args.database,
                username=args.username,
                password=args.password,
                overwrite=not args.no_overwrite,
                port=args.port,
                use_https=args.https
            )
            
            print(f"\n✓ Deployment successful!")
            print(f"  Database: {result['database']}")
            print(f"  Server: {result['server']}")
            sys.exit(0)
            
        except SSASDeploymentError as e:
            print(f"\n✗ Deployment failed: {e}", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"\n✗ Unexpected error: {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == '__main__':
    main()
