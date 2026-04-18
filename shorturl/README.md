# Short URL Service

A simple URL shortening service with SQLite storage.

## Requirements

- Python 3.8+
- Flask

## Installation

```bash
pip install flask
```

## Running the Service

```bash
cd shorturl
python app.py
```

The service starts on `http://0.0.0.0:5000`.

## API Endpoints

### Create Short URL

```bash
POST /shorten
Content-Type: application/json

{"url": "https://example.com"}
```

Response:
```json
{"short_code": "abc1234"}
```

### Redirect

```bash
GET /{short_code}
```

Returns 302 redirect to the original URL and increments click count.

### Get Stats

```bash
GET /stats/{short_code}
```

Response:
```json
{"url": "https://example.com", "clicks": 42}
```

## Running Tests

```bash
cd shorturl
python -m pytest test_app.py -v
```

Or with unittest:

```bash
cd shorturl
python test_app.py
```
