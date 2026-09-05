Take a screenshot of the running After Burner game.

The game has a built-in TCP server (mcp_bridge_game.gd autoload, port 9501) that captures the viewport and returns it as base64 PNG.

Steps:
1. Run this command to capture:
```
echo '{"cmd":"screenshot"}' | nc -w 3 127.0.0.1 9501 | python3 -c "
import sys, json, base64
data = sys.stdin.read()
if not data:
    print('ERROR: No response. Is the game running?')
    sys.exit(1)
resp = json.loads(data)
if 'image_base64' in resp:
    img = base64.b64decode(resp['image_base64'])
    with open('/tmp/afterburner_screenshot.png', 'wb') as f:
        f.write(img)
    print(f'Screenshot saved ({len(img)} bytes)')
else:
    print('Error:', resp)
    sys.exit(1)
"
```
2. Read `/tmp/afterburner_screenshot.png` to view the image.

If the game is not running, launch it first:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/urizonens/dev/afterburner 2>&1 &
sleep 3
```
