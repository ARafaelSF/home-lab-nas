#!/usr/bin/env python3
"""Enriquece o MQTT do WUD→HA com data da imagem remota (result_created)
e templates de versão no formato Telegram: ``12/09 11:08 (eda6a798)``.

O WUD deixa ``result.created`` a null na maior parte dos digests; sem isto a
dash Docker só mostra a data da versão actual. Corre depois de cada watch
(stagger) ou sob demanda.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

TZ = ZoneInfo(os.environ.get("TZ", "America/Sao_Paulo"))
WUD_API = os.environ.get("WUD_API", "http://127.0.0.1:3000/api/containers")
MQTT_HOST = os.environ.get("WUD_MQTT_HOST", "192.168.3.10")
MQTT_USER = os.environ.get("WUD_MQTT_USER", "homeassistant")
MQTT_PASS = os.environ.get(
    "WUD_MQTT_PASSWORD",
    os.environ.get("WUD_TRIGGER_MQTT_HA_PASSWORD", ""),
)
CACHE_PATH = os.environ.get(
    "WUD_ENRICH_CACHE", "/var/lib/wud-stagger/remote-created-cache.json"
)


def log(msg: str) -> None:
    print(f"[wud-enrich] {msg}", flush=True)


def run(cmd: list[str], timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd, capture_output=True, text=True, timeout=timeout, check=False
    )


def mqtt_args() -> list[str]:
    if not MQTT_PASS:
        raise SystemExit("WUD_MQTT_PASSWORD / WUD_TRIGGER_MQTT_HA_PASSWORD vazio")
    return ["-h", MQTT_HOST, "-u", MQTT_USER, "-P", MQTT_PASS]


def mqtt_get(topic: str, wait: int = 2) -> str | None:
    proc = run(
        ["mosquitto_sub", *mqtt_args(), "-t", topic, "-C", "1", "-W", str(wait)],
        timeout=wait + 5,
    )
    out = (proc.stdout or "").strip()
    return out or None


def mqtt_pub(topic: str, payload: str, retain: bool = True) -> None:
    cmd = ["mosquitto_pub", *mqtt_args(), "-t", topic, "-m", payload]
    if retain:
        cmd.append("-r")
    proc = run(cmd, timeout=15)
    if proc.returncode != 0:
        raise RuntimeError(f"mqtt pub {topic}: {proc.stderr.strip()}")


def wud_containers() -> list[dict[str, Any]]:
    # Prefer docker exec (API só escuta no container)
    proc = run(
        ["docker", "exec", "wud", "wget", "-qO-", "http://127.0.0.1:3000/api/containers"],
        timeout=30,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        raise RuntimeError(f"WUD API: {proc.stderr.strip() or 'sem resposta'}")
    return json.loads(proc.stdout)


def load_cache() -> dict[str, str]:
    try:
        with open(CACHE_PATH, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_cache(cache: dict[str, str]) -> None:
    os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
    with open(CACHE_PATH, "w", encoding="utf-8") as f:
        json.dump(cache, f, indent=2, sort_keys=True)
        f.write("\n")


def stamp_local(iso: str | None) -> str | None:
    if not iso:
        return None
    try:
        when = dt.datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone(TZ)
    except ValueError:
        return None
    return when.strftime("%d/%m %H:%M")


def short_digest(value: str | None) -> str:
    if not value:
        return ""
    return value.replace("sha256:", "")[:8]


def skopeo_auth_args(container: dict[str, Any]) -> list[str]:
    """Credenciais opcionais a partir de /etc/docker/wud-registries.env*."""
    registry = ((container.get("image") or {}).get("registry") or {}).get("name") or ""
    env: dict[str, str] = {}
    for path in (
        Path("/etc/docker/wud-registries.env"),
        Path("/etc/docker/wud-registries.env.bak.20260714090517"),
    ):
        if not path.is_file():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k] = v.strip().strip('"').strip("'")
        break
    user = token = ""
    if registry.startswith("ghcr"):
        user = env.get("WUD_REGISTRY_GHCR_PUBLIC_USERNAME", "")
        token = env.get("WUD_REGISTRY_GHCR_PUBLIC_TOKEN", "")
    elif registry.startswith("lscr"):
        user = env.get("WUD_REGISTRY_LSCR_PRIVATE_USERNAME", "")
        token = env.get("WUD_REGISTRY_LSCR_PRIVATE_TOKEN", "")
    if user and token:
        return ["--creds", f"{user}:{token}"]
    return []


def registry_refs(container: dict[str, Any]) -> list[str]:
    image = container.get("image") or {}
    result = container.get("result") or {}
    digest = result.get("digest") or ""
    if not digest.startswith("sha256:"):
        return []
    name = image.get("name") or ""
    if not name:
        return []
    registry = (image.get("registry") or {}).get("name") or ""
    refs: list[str] = []
    if registry.startswith("ghcr"):
        refs.append(f"docker://ghcr.io/{name}@{digest}")
        if name.startswith("linuxserver/"):
            refs.append(f"docker://lscr.io/{name}@{digest}")
            refs.append(f"docker://docker.io/{name}@{digest}")
    elif registry.startswith("lscr"):
        refs.append(f"docker://lscr.io/{name}@{digest}")
        refs.append(f"docker://ghcr.io/{name}@{digest}")
        refs.append(f"docker://docker.io/{name}@{digest}")
    else:
        hub_name = name.split("/", 1)[1] if name.startswith("library/") else name
        refs.append(f"docker://docker.io/{hub_name}@{digest}")
    seen: set[str] = set()
    out: list[str] = []
    for ref in refs:
        if ref not in seen:
            seen.add(ref)
            out.append(ref)
    return out


def skopeo_auth_args_for_ref(ref: str, container: dict[str, Any]) -> list[str]:
    """Só aplica credenciais ao registry correspondente ao ref."""
    if "ghcr.io/" in ref:
        fake = {"image": {"registry": {"name": "ghcr.public"}}}
        return skopeo_auth_args(fake)
    if "lscr.io/" in ref:
        fake = {"image": {"registry": {"name": "lscr.private"}}}
        return skopeo_auth_args(fake)
    return []


def remote_created(container: dict[str, Any], cache: dict[str, str]) -> str | None:
    result = container.get("result") or {}
    if result.get("created"):
        return result["created"]
    digest = result.get("digest") or ""
    if digest in cache:
        return cache[digest]
    refs = registry_refs(container)
    if not refs:
        return None
    for ref in refs:
        auth = skopeo_auth_args_for_ref(ref, container)
        try:
            proc = run(["skopeo", "inspect", *auth, ref], timeout=90)
        except subprocess.TimeoutExpired:
            log(f"skopeo timeout {container.get('name')} ({ref})")
            continue
        if proc.returncode != 0:
            log(f"skopeo falhou {container.get('name')}: {proc.stderr.strip()[:160]}")
            continue
        try:
            meta = json.loads(proc.stdout)
        except json.JSONDecodeError:
            continue
        created = meta.get("Created")
        if created:
            cache[digest] = created
            return created
    return None


def flatten_like_wud(c: dict[str, Any]) -> dict[str, Any]:
    """Aproxima o payload MQTT do WUD (campos usados pela dash / discovery)."""
    image = c.get("image") or {}
    tag = image.get("tag") or {}
    digest = image.get("digest") or {}
    registry = image.get("registry") or {}
    result = c.get("result") or {}
    update_kind = c.get("updateKind") or {}
    labels = c.get("labels") or {}

    flat: dict[str, Any] = {
        "id": c.get("id"),
        "name": c.get("name"),
        "status": c.get("status"),
        "watcher": c.get("watcher"),
        "display_name": c.get("displayName"),
        "display_icon": c.get("displayIcon"),
        "image_id": image.get("id"),
        "image_registry_name": registry.get("name"),
        "image_registry_url": registry.get("url"),
        "image_name": image.get("name"),
        "image_tag_value": tag.get("value"),
        "image_tag_semver": tag.get("semver"),
        "image_digest_watch": digest.get("watch"),
        "image_digest_repo": digest.get("repo"),
        # WUD muitas vezes só preenche `repo` (digest da imagem local);
        # o discovery HA antigo lia só `value` → installed_version vazio → unknown.
        "image_digest_value": digest.get("value") or digest.get("repo"),
        "image_architecture": image.get("architecture"),
        "image_os": image.get("os"),
        "image_created": image.get("created"),
        "result_tag": result.get("tag"),
        "result_digest": result.get("digest"),
        "result_created": result.get("created"),
        "update_available": c.get("updateAvailable"),
        "update_kind_kind": update_kind.get("kind"),
        "update_kind_local_value": update_kind.get("localValue"),
        "update_kind_remote_value": update_kind.get("remoteValue"),
    }
    for key, value in labels.items():
        safe = re.sub(r"[^a-zA-Z0-9]+", "_", key).strip("_").lower()
        flat[f"labels_{safe}"] = value
    return flat


def entity_slug(name: str) -> str:
    return name.replace("-", "_")


def version_label(stamp: str | None, digest: str | None, fallback: str) -> str:
    d = short_digest(digest)
    if stamp and d:
        return f"{stamp} ({d})"
    if d:
        return d
    return fallback


def discovery_payload(c: dict[str, Any]) -> dict[str, Any]:
    name = c["name"]
    slug = entity_slug(name)
    icon = c.get("displayIcon") or "mdi:docker"
    display = c.get("displayName") or name
    topic = f"wud/container/local/{name}"
    # Preferir digest curto quando o watch é por digest; senão tag (evita unknown
    # e evita misturar hash local com tag remota no Portainer, etc.).
    value_template = (
        "{% if value_json.update_kind_kind == 'tag'"
        " or (not value_json.image_digest_watch and value_json.image_tag_value) %}"
        "{{ value_json.image_tag_value or value_json.update_kind_local_value"
        " or ((value_json.image_digest_value or value_json.image_digest_repo or '')"
        " | replace('sha256:',''))[:8] }}"
        "{% else %}"
        "{{ ((value_json.image_digest_value or value_json.image_digest_repo or '')"
        " | replace('sha256:',''))[:8]"
        " or value_json.image_tag_value"
        " or value_json.update_kind_local_value }}"
        "{% endif %}"
    )
    latest_template = (
        "{% if value_json.update_available %}"
        "{% if value_json.update_kind_kind == 'tag' %}"
        "{{ value_json.result_tag or value_json.update_kind_remote_value }}"
        "{% else %}"
        "{{ ((value_json.result_digest or value_json.update_kind_remote_value or '')"
        " | replace('sha256:',''))[:8]"
        " or value_json.result_tag"
        " or value_json.update_kind_remote_value }}"
        "{% endif %}"
        "{% else %}"
        "{% if value_json.update_kind_kind == 'tag'"
        " or (not value_json.image_digest_watch and value_json.image_tag_value) %}"
        "{{ value_json.image_tag_value or value_json.update_kind_local_value"
        " or ((value_json.image_digest_value or value_json.image_digest_repo or '')"
        " | replace('sha256:',''))[:8] }}"
        "{% else %}"
        "{{ ((value_json.image_digest_value or value_json.image_digest_repo or '')"
        " | replace('sha256:',''))[:8]"
        " or value_json.image_tag_value"
        " or value_json.update_kind_local_value }}"
        "{% endif %}"
        "{% endif %}"
    )
    return {
        "unique_id": f"wud_container_local_{slug}",
        "default_entity_id": f"update.wud_container_local_{slug}",
        "name": display,
        "device": {
            "identifiers": ["wud"],
            "manufacturer": "wud",
            "model": "wud",
            "name": "wud",
        },
        "icon": icon,
        "entity_picture": "https://github.com/getwud/wud/raw/main/docs/assets/wud-logo-256.png",
        "state_topic": topic,
        "force_update": True,
        "value_template": value_template,
        "latest_version_topic": topic,
        "latest_version_template": latest_template,
        "json_attributes_topic": topic,
    }


def enrich_one(c: dict[str, Any], cache: dict[str, str]) -> bool:
    name = c.get("name")
    if not name:
        return False

    created_remote = None
    if c.get("updateAvailable"):
        created_remote = remote_created(c, cache)

    flat = flatten_like_wud(c)
    # Prefer retained MQTT payload (preserva labels extra do WUD) e só faz patch.
    topic = f"wud/container/local/{name}"
    retained = mqtt_get(topic, wait=1)
    payload: dict[str, Any]
    if retained:
        try:
            payload = json.loads(retained)
        except json.JSONDecodeError:
            payload = flat
    else:
        payload = flat

    if created_remote:
        payload["result_created"] = created_remote
        # mirror nested shape if present
        if isinstance(c.get("result"), dict):
            c["result"]["created"] = created_remote

    # Garantir campos que o discovery HA usa (payload retained do WUD pode omitir value).
    if not payload.get("image_digest_value") and payload.get("image_digest_repo"):
        payload["image_digest_value"] = payload["image_digest_repo"]
    if not payload.get("image_tag_value"):
        payload["image_tag_value"] = ((c.get("image") or {}).get("tag") or {}).get("value")

    local_stamp = stamp_local(payload.get("image_created") or (c.get("image") or {}).get("created"))
    remote_stamp = stamp_local(payload.get("result_created"))
    local_digest = (
        payload.get("image_digest_value")
        or payload.get("image_digest_repo")
        or payload.get("update_kind_local_value")
    )
    remote_digest = payload.get("result_digest") or payload.get("update_kind_remote_value")

    payload["homelab_version_local"] = version_label(
        local_stamp, local_digest, str(payload.get("image_tag_value") or "?")
    )
    if c.get("updateAvailable"):
        payload["homelab_version_remote"] = version_label(
            remote_stamp,
            remote_digest,
            str(
                payload.get("result_tag")
                or payload.get("update_kind_remote_value")
                or short_digest(remote_digest)
                or "?"
            ),
        )
    else:
        payload["homelab_version_remote"] = payload["homelab_version_local"]

    mqtt_pub(topic, json.dumps(payload, ensure_ascii=False), retain=True)

    slug = entity_slug(name)
    disc_topic = f"homeassistant/update/wud_container_local_{slug}/config"
    # Keep existing discovery keys when possible (device sw_version etc.)
    existing = mqtt_get(disc_topic, wait=1)
    disc = discovery_payload(c)
    if existing:
        try:
            old = json.loads(existing)
            if isinstance(old.get("device"), dict):
                disc["device"] = {**disc["device"], **old["device"]}
            for key in ("icon", "entity_picture", "name"):
                if old.get(key):
                    disc[key] = old[key]
        except json.JSONDecodeError:
            pass
    mqtt_pub(disc_topic, json.dumps(disc, ensure_ascii=False), retain=True)

    if c.get("updateAvailable"):
        log(
            f"{name}: {payload['homelab_version_local']} -> {payload['homelab_version_remote']}"
        )
    return True


def main() -> int:
    args = sys.argv[1:]
    fix_all = "--all" in args
    only = [a for a in args if a != "--all"]
    containers = wud_containers()
    cache = load_cache()
    done = 0
    pending = 0
    for c in containers:
        name = c.get("name") or ""
        if only and name not in only and entity_slug(name) not in only:
            continue
        # --all: republicar discovery/payload de todos (corrige unknown no HA)
        # senão: só pendentes, ou os nomes pedidos na CLI
        if not (fix_all or only or c.get("updateAvailable")):
            continue
        if c.get("updateAvailable"):
            pending += 1
        try:
            if enrich_one(c, cache):
                done += 1
        except Exception as exc:  # noqa: BLE001
            log(f"ERRO {name}: {exc}")
    save_cache(cache)
    log(f"concluído: {done} containers (pendentes WUD={pending})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
