import urllib.request

req = urllib.request.Request('http://localhost:8000/reclamos', headers={'Origin': 'http://localhost:5174'})
with urllib.request.urlopen(req, timeout=10) as resp:
    print(resp.status)
    print(resp.headers.get('access-control-allow-origin'))
    print(resp.read().decode('utf-8'))
