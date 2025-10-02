"""
Unit tests for pyssas-deploy.
"""

import json
import os
import tempfile
import unittest
from unittest.mock import patch, MagicMock
from pyssas_deploy.deploy import (
    load_bim_file,
    create_tmsl_script,
    deploy_bim,
    SSASDeploymentError
)


class TestLoadBimFile(unittest.TestCase):
    """Test BIM file loading functionality."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.test_bim_data = {
            "name": "TestModel",
            "compatibilityLevel": 1500,
            "model": {
                "culture": "en-US",
                "tables": []
            }
        }
    
    def test_load_valid_bim_file(self):
        """Test loading a valid .bim file."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.bim', delete=False) as f:
            json.dump(self.test_bim_data, f)
            temp_path = f.name
        
        try:
            result = load_bim_file(temp_path)
            self.assertEqual(result, self.test_bim_data)
        finally:
            os.unlink(temp_path)
    
    def test_load_nonexistent_file(self):
        """Test loading a non-existent file raises error."""
        with self.assertRaises(SSASDeploymentError) as cm:
            load_bim_file('/nonexistent/file.bim')
        self.assertIn('not found', str(cm.exception))
    
    def test_load_invalid_json(self):
        """Test loading invalid JSON raises error."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.bim', delete=False) as f:
            f.write("invalid json {")
            temp_path = f.name
        
        try:
            with self.assertRaises(SSASDeploymentError) as cm:
                load_bim_file(temp_path)
            self.assertIn('Invalid BIM file format', str(cm.exception))
        finally:
            os.unlink(temp_path)


class TestCreateTMSLScript(unittest.TestCase):
    """Test TMSL script creation."""
    
    def test_create_basic_tmsl_script(self):
        """Test creating a basic TMSL script."""
        bim_data = {"name": "TestModel"}
        database_name = "TestDB"
        
        result = create_tmsl_script(bim_data, database_name)
        
        self.assertIn('createOrReplace', result)
        self.assertEqual(result['createOrReplace']['object']['database'], database_name)
        self.assertEqual(result['createOrReplace']['database'], bim_data)


class TestDeployBim(unittest.TestCase):
    """Test BIM deployment functionality."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.test_bim_data = {
            "name": "TestModel",
            "compatibilityLevel": 1500,
            "model": {"culture": "en-US", "tables": []}
        }
        
        # Create temporary BIM file
        self.temp_bim = tempfile.NamedTemporaryFile(mode='w', suffix='.bim', delete=False)
        json.dump(self.test_bim_data, self.temp_bim)
        self.temp_bim.close()
    
    def tearDown(self):
        """Clean up test fixtures."""
        if os.path.exists(self.temp_bim.name):
            os.unlink(self.temp_bim.name)
    
    @patch('pyssas_deploy.deploy.requests.post')
    def test_successful_deployment(self, mock_post):
        """Test successful BIM deployment."""
        # Mock successful response
        mock_response = MagicMock()
        mock_response.json.return_value = {"status": "success"}
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response
        
        result = deploy_bim(
            bim_path=self.temp_bim.name,
            server="testserver",
            database_name="TestDB"
        )
        
        self.assertEqual(result['status'], 'success')
        self.assertEqual(result['database'], 'TestDB')
        self.assertEqual(result['server'], 'testserver')
        
        # Verify the request was made correctly
        mock_post.assert_called_once()
        args, kwargs = mock_post.call_args
        self.assertEqual(args[0], 'http://testserver:2383/xmla')
    
    @patch('pyssas_deploy.deploy.requests.post')
    def test_deployment_with_auth(self, mock_post):
        """Test deployment with authentication."""
        mock_response = MagicMock()
        mock_response.json.return_value = {"status": "success"}
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response
        
        deploy_bim(
            bim_path=self.temp_bim.name,
            server="testserver",
            database_name="TestDB",
            username="admin",
            password="password"
        )
        
        # Verify auth was passed
        args, kwargs = mock_post.call_args
        self.assertIsNotNone(kwargs.get('auth'))
    
    @patch('pyssas_deploy.deploy.requests.post')
    def test_deployment_with_https(self, mock_post):
        """Test deployment with HTTPS."""
        mock_response = MagicMock()
        mock_response.json.return_value = {"status": "success"}
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response
        
        deploy_bim(
            bim_path=self.temp_bim.name,
            server="testserver",
            database_name="TestDB",
            use_https=True
        )
        
        # Verify HTTPS was used
        args, kwargs = mock_post.call_args
        self.assertTrue(args[0].startswith('https://'))
    
    @patch('pyssas_deploy.deploy.requests.post')
    def test_deployment_failure(self, mock_post):
        """Test deployment failure handling."""
        mock_post.side_effect = Exception("Connection failed")
        
        with self.assertRaises(SSASDeploymentError) as cm:
            deploy_bim(
                bim_path=self.temp_bim.name,
                server="testserver",
                database_name="TestDB"
            )
        self.assertIn('Connection failed', str(cm.exception))


if __name__ == '__main__':
    unittest.main()
