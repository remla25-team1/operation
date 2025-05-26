import requests
import re

repos = [
    ("operation", "remla25-team1/operation"),
    ("model training", "remla25-team1/model-training"),
    ("model service", "remla25-team1/model-service"),
    ("lib-ml", "remla25-team1/lib-ml"),
    ("app", "remla25-team1/app"),
    ("lib-version", "remla25-team1/lib-version"),
]

lines = []
for name, repo in repos:
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    r = requests.get(url)
    repo_url = f"https://github.com/{repo}"
    if r.status_code == 200:
        tag = r.json()["tag_name"]
        release_url = f"https://github.com/{repo}/releases/latest"
        # Make the tag a clickable link
        tag_link = f"[`{tag}`]({release_url})"
        lines.append(f"- **{name}:** [repo]({repo_url}) | latest release: {tag_link}")
    else:
        lines.append(f"- **{name}:** [repo]({repo_url}) | No release out yet")

new_section = "\n".join(lines)

with open("md/PEER.md", "r") as f:
    content = f.read()

pattern = r"(<!-- REPO LINKS START -->)(.*?)(<!-- REPO LINKS END -->)"
replacement = r"\1\n" + new_section + r"\n\3"
new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open("md/PEER.md", "w") as f:
    f.write(new_content)