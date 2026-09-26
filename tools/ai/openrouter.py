"""Minimal OpenRouter client for agent decisions and visual critiques.

Reads OPENROUTER_API_KEY from the environment (falls back to the Windows user variable).
Never prints the key.

  python tools/ai/openrouter.py -m typesafe/jev-router "question"
  python tools/ai/openrouter.py -m ~google/gemini-pro-latest -i a.png -i b.png "Which is better, A or B?"
"""
import argparse
import base64
import json
import mimetypes
import os
import sys
import urllib.request


def api_key() -> str:
    key = os.environ.get("OPENROUTER_API_KEY", "")
    if not key and sys.platform == "win32":
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as reg:
            key = winreg.QueryValueEx(reg, "OPENROUTER_API_KEY")[0]
    if not key:
        sys.exit("OPENROUTER_API_KEY not set")
    return key


def image_part(path: str) -> dict:
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode()
    return {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{data}"}}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-m", "--model", default="typesafe/jev-router")
    parser.add_argument("-i", "--image", action="append", default=[])
    parser.add_argument("-s", "--system", default="")
    parser.add_argument("--max-tokens", type=int, default=1500)
    parser.add_argument("prompt")
    args = parser.parse_args()
    content: list = [{"type": "text", "text": args.prompt}] + [image_part(p) for p in args.image]
    messages = ([{"role": "system", "content": args.system}] if args.system else []) + [{"role": "user", "content": content}]
    body = json.dumps({"model": args.model, "messages": messages, "max_tokens": args.max_tokens}).encode()
    request = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", data=body, headers={
        "Authorization": f"Bearer {api_key()}", "Content-Type": "application/json",
        "X-Title": "DynMagic agents"})
    with urllib.request.urlopen(request, timeout=300) as response:
        data = json.load(response)
    print(data["choices"][0]["message"]["content"])
    usage = data.get("usage", {})
    print(f"\n[model={data.get('model')} tokens={usage.get('total_tokens')} cost={usage.get('cost')}]", file=sys.stderr)


if __name__ == "__main__":
    main()
