#!/usr/bin/env python3
"""Semnează arhiva pentru Sparkle (EdDSA) și scrie appcast.xml.

Cheia privată vine din variabila de mediu SPARKLE_KEY (secretul SPARKLE_ED_PRIVATE_KEY).
Verifică întâi că se potrivește cu cheia publică din Info.plist, ca să nu publicăm
o versiune pe care aplicațiile instalate ar refuza-o.
"""
import argparse
import base64
import datetime
import html
import os
import plistlib
import sys

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

parser = argparse.ArgumentParser()
parser.add_argument("--zip", required=True)
parser.add_argument("--version", required=True)
parser.add_argument("--build", required=True)
parser.add_argument("--tag", required=True)
parser.add_argument("--repo", required=True)
parser.add_argument("--notes", default="")
parser.add_argument("--info-plist", default="Info.plist")
parser.add_argument("--out", required=True)
args = parser.parse_args()

raw_key = os.environ.get("SPARKLE_KEY", "").strip()
if not raw_key:
    sys.exit("Lipsește secretul SPARKLE_ED_PRIVATE_KEY.")
seed = base64.b64decode(raw_key)
if len(seed) == 64:  # format vechi Sparkle: seed + cheie publică
    seed = seed[:32]
key = Ed25519PrivateKey.from_private_bytes(seed)

public = base64.b64encode(
    key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
).decode()
with open(args.info_plist, "rb") as f:
    expected = plistlib.load(f).get("SUPublicEDKey", "")
if public != expected:
    sys.exit("Cheia SPARKLE_ED_PRIVATE_KEY nu se potrivește cu SUPublicEDKey din Info.plist.")

with open(args.zip, "rb") as f:
    data = f.read()
signature = base64.b64encode(key.sign(data)).decode()

name = os.path.basename(args.zip)
url = f"https://github.com/{args.repo}/releases/download/{args.tag}/{name}"
published = datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
notes = "<br>".join(html.escape(line) for line in args.notes.strip().splitlines()) or "Îmbunătățiri"

appcast = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Sortator</title>
    <item>
      <title>Sortator {html.escape(args.version)}</title>
      <pubDate>{published}</pubDate>
      <sparkle:version>{html.escape(args.build)}</sparkle:version>
      <sparkle:shortVersionString>{html.escape(args.version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[{notes}]]></description>
      <enclosure url="{url}" length="{len(data)}" type="application/octet-stream" sparkle:edSignature="{signature}"/>
    </item>
  </channel>
</rss>
"""
with open(args.out, "w", encoding="utf-8") as f:
    f.write(appcast)
print(f"appcast scris: {args.out} ({name}, {len(data)} bytes)")
