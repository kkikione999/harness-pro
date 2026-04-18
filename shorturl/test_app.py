"""
Unit tests for Short URL Service.
"""
import unittest
import sys
import os
import sqlite3
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import app, init_db, DATABASE

class TestShortURLService(unittest.TestCase):
    """Test cases for the Short URL Service."""

    def setUp(self):
        """Set up test fixtures."""
        # Use a temporary database for testing
        self.db_fd, app.config['DATABASE'] = tempfile.mkstemp()
        app.config['TESTING'] = True

        with app.app_context():
            init_db()

        self.client = app.test_client()

    def tearDown(self):
        """Tear down test fixtures."""
        os.close(self.db_fd)
        os.unlink(app.config['DATABASE'])

    def test_shorten_missing_url(self):
        """Test POST /shorten with missing URL."""
        response = self.client.post('/shorten', json={})
        self.assertEqual(response.status_code, 400)

    def test_shorten_invalid_url(self):
        """Test POST /shorten with invalid URL format."""
        response = self.client.post('/shorten', json={'url': 'not-a-url'})
        self.assertEqual(response.status_code, 400)

    def test_shorten_valid_url(self):
        """Test POST /shorten with valid URL."""
        response = self.client.post('/shorten', json={'url': 'https://example.com'})
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn('short_code', data)
        self.assertEqual(len(data['short_code']), 7)

    def test_shorten_generates_unique_codes(self):
        """Test that same URL generates different short codes."""
        url = 'https://example.com/page1'
        codes = set()

        for _ in range(10):
            response = self.client.post('/shorten', json={'url': url})
            data = response.get_json()
            codes.add(data['short_code'])

        # All codes should be unique (probability of collision is negligible)
        self.assertEqual(len(codes), 10)

    def test_short_code_format(self):
        """Test that short codes are 7 characters of a-z0-9."""
        response = self.client.post('/shorten', json={'url': 'https://test.com'})
        data = response.get_json()
        code = data['short_code']

        self.assertEqual(len(code), 7)
        self.assertTrue(all(c in 'abcdefghijklmnopqrstuvwxyz0123456789' for c in code))

    def test_redirect_nonexistent_code(self):
        """Test GET /{short_code} with non-existent code returns 404."""
        response = self.client.get('/nonexistent')
        self.assertEqual(response.status_code, 404)

    def test_redirect_and_increment_clicks(self):
        """Test that redirect increments click count."""
        # Create a short URL
        create_response = self.client.post('/shorten', json={'url': 'https://example.com'})
        short_code = create_response.get_json()['short_code']

        # Get initial stats
        stats_response = self.client.get(f'/stats/{short_code}')
        initial_clicks = stats_response.get_json()['clicks']
        self.assertEqual(initial_clicks, 0)

        # Perform redirect
        redirect_response = self.client.get(f'/{short_code}')
        self.assertEqual(redirect_response.status_code, 302)

        # Check clicks incremented
        stats_response = self.client.get(f'/stats/{short_code}')
        new_clicks = stats_response.get_json()['clicks']
        self.assertEqual(new_clicks, 1)

    def test_stats_nonexistent_code(self):
        """Test GET /stats/{short_code} with non-existent code returns 404."""
        response = self.client.get('/stats/nonexistent')
        self.assertEqual(response.status_code, 404)

    def test_stats_returns_correct_data(self):
        """Test that stats returns URL and click count."""
        # Create a short URL
        original_url = 'https://example.com/path?query=1'
        create_response = self.client.post('/shorten', json={'url': original_url})
        short_code = create_response.get_json()['short_code']

        # Perform a few redirects
        for _ in range(3):
            self.client.get(f'/{short_code}')

        # Check stats
        stats_response = self.client.get(f'/stats/{short_code}')
        data = stats_response.get_json()

        self.assertEqual(data['url'], original_url)
        self.assertEqual(data['clicks'], 3)

if __name__ == '__main__':
    unittest.main()
