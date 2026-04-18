"""
Short URL Service

A simple URL shortening service with SQLite storage.
"""
import sqlite3
import random
import string
from flask import Flask, request, jsonify, redirect, abort

DATABASE = 'shorturl.db'
app = Flask(__name__)

def get_db():
    """Get database connection with row factory."""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initialize the database schema."""
    conn = get_db()
    conn.execute('''
        CREATE TABLE IF NOT EXISTS urls (
            short_code TEXT PRIMARY KEY,
            original_url TEXT NOT NULL,
            clicks INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

def generate_short_code(length=7):
    """Generate a random short code with a-z0-9 characters."""
    chars = string.ascii_lowercase + string.digits
    return ''.join(random.choice(chars) for _ in range(length))

def is_short_code_unique(code):
    """Check if a short code already exists in the database."""
    conn = get_db()
    cursor = conn.execute('SELECT 1 FROM urls WHERE short_code = ?', (code,))
    exists = cursor.fetchone() is not None
    conn.close()
    return not exists

def create_short_code():
    """Generate a unique short code."""
    while True:
        code = generate_short_code()
        if is_short_code_unique(code):
            return code

@app.route('/shorten', methods=['POST'])
def shorten():
    """Create a new short URL."""
    data = request.get_json()
    if not data or 'url' not in data:
        abort(400, description="Missing 'url' in request body")

    original_url = data['url']
    if not original_url.startswith(('http://', 'https://')):
        abort(400, description="URL must start with http:// or https://")

    short_code = create_short_code()

    conn = get_db()
    conn.execute(
        'INSERT INTO urls (short_code, original_url) VALUES (?, ?)',
        (short_code, original_url)
    )
    conn.commit()
    conn.close()

    return jsonify({'short_code': short_code})

@app.route('/<short_code>', methods=['GET'])
def redirect_to_url(short_code):
    """Redirect to the original URL and increment click count."""
    conn = get_db()
    cursor = conn.execute(
        'SELECT original_url FROM urls WHERE short_code = ?',
        (short_code,)
    )
    row = cursor.fetchone()

    if row is None:
        conn.close()
        abort(404, description="Short code not found")

    original_url = row['original_url']
    conn.execute(
        'UPDATE urls SET clicks = clicks + 1 WHERE short_code = ?',
        (short_code,)
    )
    conn.commit()
    conn.close()

    return redirect(original_url, code=302)

@app.route('/stats/<short_code>', methods=['GET'])
def get_stats(short_code):
    """Get statistics for a short URL."""
    conn = get_db()
    cursor = conn.execute(
        'SELECT original_url, clicks FROM urls WHERE short_code = ?',
        (short_code,)
    )
    row = cursor.fetchone()
    conn.close()

    if row is None:
        abort(404, description="Short code not found")

    return jsonify({
        'url': row['original_url'],
        'clicks': row['clicks']
    })

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000, debug=True)
