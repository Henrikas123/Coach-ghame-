#!/usr/bin/env python3
"""Atsisiunčia peržiūros įrankiui reikalingus failus į tools/ui-preview/cache/:
  - Roblox API dump (savybių/enum validacijai mock'e) -> cache/api.json
  - Montserrat (Gotham pakaitalas) ir Noto Color Emoji šriftus -> cache/fonts/
"""
import json, os, re, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cache")
FONTS = os.path.join(CACHE, "fonts")
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r:
        return r.read()


def fetch_api():
    version = get("https://setup.rbxcdn.com/versionQTStudio").decode().strip()
    dump = json.loads(get(f"https://setup.rbxcdn.com/{version}-API-Dump.json"))
    classes = {}
    for c in dump["Classes"]:
        props, events, funcs = {}, [], []
        for m in c["Members"]:
            tags = [t for t in (m.get("Tags") or []) if isinstance(t, str)]
            if m["MemberType"] == "Property":
                vt = m["ValueType"]
                sec = m.get("Security", {})
                props[m["Name"]] = {
                    "type": vt["Name"], "cat": vt["Category"],
                    "ro": "ReadOnly" in tags or "NotScriptable" in tags,
                    "dep": "Deprecated" in tags,
                    "sec": sec.get("Write", "None") if isinstance(sec, dict) else sec,
                }
            elif m["MemberType"] == "Event":
                events.append(m["Name"])
            elif m["MemberType"] in ("Function", "YieldFunction"):
                funcs.append(m["Name"])
        classes[c["Name"]] = {"super": c["Superclass"], "props": props, "events": events, "funcs": funcs,
                              "tags": [t for t in (c.get("Tags") or []) if isinstance(t, str)]}
    enums = {e["Name"]: {i["Name"]: i["Value"] for i in e["Items"]} for e in dump["Enums"]}
    with open(os.path.join(CACHE, "api.json"), "w") as f:
        json.dump({"classes": classes, "enums": enums}, f)
    print("api.json:", version, len(classes), "klasės")


def fetch_fonts():
    os.makedirs(FONTS, exist_ok=True)
    css = get("https://fonts.googleapis.com/css2?family=Montserrat:wght@500;700&family=Noto+Color+Emoji&display=swap").decode()
    out = []
    for n, (_, subset, body) in enumerate(re.findall(r"(/\* ([^*]*?) \*/\s*)?@font-face \{(.*?)\}", css, re.S)):
        family = re.search(r"font-family: '([^']+)'", body).group(1)
        if family == "Montserrat" and subset not in ("latin", "latin-ext"):
            continue
        url = re.search(r"url\((.*?)\)", body).group(1)
        name = f"f{n}.woff2"
        with open(os.path.join(FONTS, name), "wb") as f:
            f.write(get(url))
        out.append("@font-face {" + body.replace(url, name) + "}")
    with open(os.path.join(FONTS, "local-fonts.css"), "w") as f:
        f.write("\n".join(out))
    print("šriftai:", len(out), "failai")


if __name__ == "__main__":
    os.makedirs(CACHE, exist_ok=True)
    fetch_api()
    fetch_fonts()
