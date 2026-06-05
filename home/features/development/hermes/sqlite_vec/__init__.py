"""SQLite + sqlite-vec local memory provider for Hermes.

This provider is a local-first semantic-ish recall layer. It is not a
replacement for built-in curated memory; it mirrors explicit memory writes and
optionally stores manually supplied notes/facts through provider tools.
"""

from __future__ import annotations

import hashlib
import json
import logging
import math
import os
import re
import sqlite3
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

from agent.memory_provider import MemoryProvider
from tools.registry import tool_error

logger = logging.getLogger(__name__)

_CONFIG_KEY = "sqlite_vec"
_DEFAULT_CONFIG = {
    "db_path": "$HERMES_HOME/sqlite_vec_memory.db",
    "embedding_dim": 384,
    "top_k": 5,
    "max_distance": 1.35,
    "auto_capture": False,
    "capture_delegations": False,
}

_SECRET_PATTERNS = [
    re.compile(r"\b(?:sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"),
    re.compile(r"\b(?:api[_-]?key|token|secret|password|passwd|authorization|bearer)\b\s*[:=]", re.I),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\b[A-Za-z0-9+/]{40,}={0,2}\b"),
]
_TOKEN_RE = re.compile(r"[A-Za-z][A-Za-z0-9_./:-]{1,}")


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _json_dumps(value: Any) -> str:
    if value is None:
        value = {}
    return json.dumps(value, sort_keys=True, ensure_ascii=False)


def _looks_secret(text: str) -> bool:
    if not text:
        return False
    return any(pattern.search(text) for pattern in _SECRET_PATTERNS)


def _as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _expand_path(path: str, hermes_home: str) -> str:
    return os.path.expanduser(
        str(path)
        .replace("$HERMES_HOME", hermes_home)
        .replace("${HERMES_HOME}", hermes_home)
    )


def _load_config(hermes_home: Optional[str] = None) -> dict:
    try:
        import yaml
        from hermes_constants import get_hermes_home

        home = Path(hermes_home) if hermes_home else get_hermes_home()
        merged = dict(_DEFAULT_CONFIG)

        sidecar_path = home / "sqlite_vec_memory.json"
        if sidecar_path.exists():
            try:
                merged.update(json.loads(sidecar_path.read_text(encoding="utf-8")) or {})
            except Exception as exc:
                logger.debug("sqlite_vec sidecar config load failed: %s", exc)

        config_path = home / "config.yaml"
        if config_path.exists():
            with open(config_path, encoding="utf-8-sig") as f:
                full = yaml.safe_load(f) or {}
            plugin_config = ((full.get("plugins") or {}).get(_CONFIG_KEY) or {})
            merged.update(plugin_config)
        return merged
    except Exception as exc:
        logger.debug("sqlite_vec config load failed: %s", exc)
        return dict(_DEFAULT_CONFIG)


class SQLiteVecMemoryProvider(MemoryProvider):
    """Local vector recall using SQLite and sqlite-vec."""

    def __init__(self, config: Optional[dict] = None):
        self._config = config or _load_config()
        self._conn: Optional[sqlite3.Connection] = None
        self._sqlite_vec = None
        self._lock = threading.RLock()
        self._session_id = ""
        self._hermes_home = ""
        self._profile = "default"
        self._dim = int(self._config.get("embedding_dim", 384))
        self._top_k = int(self._config.get("top_k", 5))
        self._max_distance = float(self._config.get("max_distance", 1.35))
        self._auto_capture = _as_bool(self._config.get("auto_capture", False))
        self._capture_delegations = _as_bool(self._config.get("capture_delegations", False))

    @property
    def name(self) -> str:
        return "sqlite_vec"

    def is_available(self) -> bool:
        try:
            import sqlite_vec  # noqa: F401
            return hasattr(sqlite3.Connection, "enable_load_extension")
        except Exception:
            return False

    def get_config_schema(self) -> List[Dict[str, Any]]:
        return [
            {"key": "db_path", "description": "SQLite database path", "default": "$HERMES_HOME/sqlite_vec_memory.db"},
            {"key": "embedding_dim", "description": "Deterministic local embedding dimensions", "default": "384"},
            {"key": "top_k", "description": "Default recall result count", "default": "5"},
            {"key": "max_distance", "description": "Maximum sqlite-vec L2 distance to inject", "default": "1.35"},
            {"key": "auto_capture", "description": "Automatically store completed turns", "default": "false", "choices": ["true", "false"]},
            {"key": "capture_delegations", "description": "Automatically store subagent task/result summaries", "default": "false", "choices": ["true", "false"]},
        ]

    def save_config(self, values: Dict[str, Any], hermes_home: str) -> None:
        from pathlib import Path
        import yaml

        config_path = Path(hermes_home) / "config.yaml"
        existing = {}
        if config_path.exists():
            with open(config_path, encoding="utf-8-sig") as f:
                existing = yaml.safe_load(f) or {}
        existing.setdefault("plugins", {})
        merged = dict(_DEFAULT_CONFIG)
        merged.update(values or {})
        existing["plugins"][_CONFIG_KEY] = merged
        with open(config_path, "w", encoding="utf-8") as f:
            yaml.safe_dump(existing, f, default_flow_style=False, sort_keys=False)

    def initialize(self, session_id: str, **kwargs) -> None:
        import sqlite_vec

        self._sqlite_vec = sqlite_vec
        self._session_id = session_id or ""
        self._hermes_home = str(kwargs.get("hermes_home") or os.path.expanduser("~/.hermes"))
        self._profile = str(kwargs.get("agent_identity") or "default")
        self._config = _load_config(self._hermes_home)
        self._dim = int(self._config.get("embedding_dim", self._dim))
        self._top_k = int(self._config.get("top_k", self._top_k))
        self._max_distance = float(self._config.get("max_distance", self._max_distance))
        self._auto_capture = _as_bool(self._config.get("auto_capture", self._auto_capture))
        self._capture_delegations = _as_bool(self._config.get("capture_delegations", self._capture_delegations))

        db_path = _expand_path(self._config.get("db_path", _DEFAULT_CONFIG["db_path"]), self._hermes_home)
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(db_path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.enable_load_extension(True)
        sqlite_vec.load(conn)
        conn.enable_load_extension(False)
        self._conn = conn
        self._ensure_schema()

    def system_prompt_block(self) -> str:
        count = 0
        if self._conn:
            try:
                count = int(self._conn.execute("SELECT COUNT(*) FROM memories WHERE deleted_at IS NULL").fetchone()[0])
            except Exception:
                count = 0
        return (
            "# SQLite Vec Memory\n"
            f"Active local vector recall with {count} stored items. "
            "Use sqlite_vec_search for fuzzy recall and sqlite_vec_store for large/project notes. "
            "Keep built-in memory tiny; never store secrets or credentials."
        )

    def prefetch(self, query: str, *, session_id: str = "") -> str:
        if not query or not self._conn:
            return ""
        try:
            results = self._search(query, limit=self._top_k)
            filtered = [r for r in results if float(r.get("distance", 99.0)) <= self._max_distance]
            if not filtered:
                return ""
            lines = ["## SQLite Vec Memory"]
            for r in filtered:
                source = r.get("source") or r.get("kind") or "memory"
                lines.append(f"- [id={r['id']} d={float(r['distance']):.3f} source={source}] {r['content'][:700]}")
            return "\n".join(lines)
        except Exception as exc:
            logger.debug("sqlite_vec prefetch failed: %s", exc)
            return ""

    def sync_turn(self, user_content: str, assistant_content: str, *, session_id: str = "") -> None:
        if not self._auto_capture:
            return
        content = (user_content or "").strip()
        if not content or len(content) < 30 or _looks_secret(content):
            return
        # Store user requests, not assistant narration, to reduce bloat.
        self._store(content[:2000], kind="turn", source="sync_turn", session_id=session_id or self._session_id)

    def on_memory_write(self, action: str, target: str, content: str, metadata: Optional[Dict[str, Any]] = None) -> None:
        if action not in {"add", "replace"} or not content:
            return
        kind = "user_profile" if target == "user" else "memory"
        self._store(content, kind=kind, source="builtin_memory", session_id=(metadata or {}).get("session_id") or self._session_id, metadata=metadata)

    def on_delegation(self, task: str, result: str, *, child_session_id: str = "", **kwargs) -> None:
        if not self._capture_delegations:
            return
        text = f"Delegated task: {task[:1000]}\nResult: {result[:2000]}"
        self._store(text, kind="delegation", source="delegate_task", session_id=self._session_id, metadata={"child_session_id": child_session_id})

    def on_pre_compress(self, messages: List[Dict[str, Any]]) -> str:
        if not self._auto_capture or not messages:
            return ""
        return "SQLite Vec Memory is active; preserve durable facts as explicit memory/notes rather than raw transcript."

    def on_session_end(self, messages: List[Dict[str, Any]]) -> None:
        # Deliberately no automatic transcript ingestion by default. Large raw
        # transcript storage belongs behind explicit auto_capture opt-in.
        return

    def get_tool_schemas(self) -> List[Dict[str, Any]]:
        return [
            {
                "name": "sqlite_vec_store",
                "description": "Store a non-secret note/fact/document chunk in local SQLite+sqlite-vec recall. Use for large fuzzy-retrievable context, not tiny always-on memory.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "content": {"type": "string", "description": "Text to store. Must not contain secrets."},
                        "kind": {"type": "string", "description": "Category such as note, project, decision, research, memory."},
                        "source": {"type": "string", "description": "Path/URL/source label for provenance."},
                        "tags": {"type": "array", "items": {"type": "string"}},
                        "metadata": {"type": "object", "description": "Optional JSON-serializable metadata."},
                    },
                    "required": ["content"],
                },
            },
            {
                "name": "sqlite_vec_search",
                "description": "Search local SQLite+sqlite-vec memory for semantically/fuzzily related stored notes with provenance.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "query": {"type": "string"},
                        "limit": {"type": "integer", "default": 5},
                        "kind": {"type": "string", "description": "Optional kind/category filter."},
                    },
                    "required": ["query"],
                },
            },
            {
                "name": "sqlite_vec_list",
                "description": "List recent local vector memory entries for inspection/hygiene.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "limit": {"type": "integer", "default": 20},
                        "kind": {"type": "string"},
                    },
                },
            },
            {
                "name": "sqlite_vec_forget",
                "description": "Soft-delete a local vector memory entry by id.",
                "parameters": {
                    "type": "object",
                    "properties": {"memory_id": {"type": "integer"}},
                    "required": ["memory_id"],
                },
            },
        ]

    def handle_tool_call(self, tool_name: str, args: Dict[str, Any], **kwargs) -> str:
        try:
            if tool_name == "sqlite_vec_store":
                memory_id = self._store(
                    args.get("content", ""),
                    kind=args.get("kind", "note"),
                    source=args.get("source", "manual"),
                    tags=args.get("tags") or [],
                    metadata=args.get("metadata") or {},
                )
                return json.dumps({"status": "stored", "id": memory_id})
            if tool_name == "sqlite_vec_search":
                results = self._search(args.get("query", ""), limit=int(args.get("limit", self._top_k)), kind=args.get("kind"))
                return json.dumps({"results": results, "count": len(results)}, ensure_ascii=False)
            if tool_name == "sqlite_vec_list":
                results = self._list(limit=int(args.get("limit", 20)), kind=args.get("kind"))
                return json.dumps({"results": results, "count": len(results)}, ensure_ascii=False)
            if tool_name == "sqlite_vec_forget":
                removed = self._forget(int(args["memory_id"]))
                return json.dumps({"removed": removed})
            return tool_error(f"Unknown sqlite_vec tool: {tool_name}")
        except KeyError as exc:
            return tool_error(f"Missing required argument: {exc}")
        except ValueError as exc:
            return tool_error(str(exc))
        except Exception as exc:
            logger.exception("sqlite_vec tool failed")
            return tool_error(str(exc))

    def shutdown(self) -> None:
        with self._lock:
            if self._conn:
                self._conn.close()
                self._conn = None

    def _ensure_schema(self) -> None:
        assert self._conn is not None
        with self._lock:
            self._conn.execute(
                """
                CREATE TABLE IF NOT EXISTS memories (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    content TEXT NOT NULL,
                    kind TEXT NOT NULL DEFAULT 'note',
                    source TEXT NOT NULL DEFAULT 'manual',
                    profile TEXT NOT NULL DEFAULT 'default',
                    session_id TEXT NOT NULL DEFAULT '',
                    tags_json TEXT NOT NULL DEFAULT '[]',
                    metadata_json TEXT NOT NULL DEFAULT '{}',
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    deleted_at TEXT
                )
                """
            )
            self._conn.execute(
                f"CREATE VIRTUAL TABLE IF NOT EXISTS memory_vec USING vec0(embedding float[{self._dim}])"
            )
            self._conn.execute("CREATE INDEX IF NOT EXISTS idx_memories_kind ON memories(kind)")
            self._conn.execute("CREATE INDEX IF NOT EXISTS idx_memories_profile ON memories(profile)")
            self._conn.commit()

    def _embed(self, text: str) -> List[float]:
        tokens = [t.lower() for t in _TOKEN_RE.findall(text or "")]
        vec = [0.0] * self._dim
        for token in tokens:
            h = hashlib.blake2b(token.encode("utf-8"), digest_size=8).digest()
            n = int.from_bytes(h, "little", signed=False)
            idx = n % self._dim
            sign = -1.0 if ((n >> 16) & 1) else 1.0
            weight = 1.0 + min(len(token), 16) / 32.0
            vec[idx] += sign * weight
        norm = math.sqrt(sum(v * v for v in vec)) or 1.0
        return [float(v / norm) for v in vec]

    def _serialize(self, text: str) -> bytes:
        return self._sqlite_vec.serialize_float32(self._embed(text))

    def _store(
        self,
        content: str,
        *,
        kind: str = "note",
        source: str = "manual",
        session_id: str = "",
        tags: Optional[Iterable[str]] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> int:
        if not self._conn:
            raise RuntimeError("sqlite_vec provider is not initialized")
        content = (content or "").strip()
        if not content:
            raise ValueError("content is required")
        if _looks_secret(content):
            raise ValueError("refusing to store content that looks like a secret; use a vault pointer instead")
        now = _utc_now()
        tags_list = list(tags or [])
        metadata_obj = dict(metadata or {})
        with self._lock:
            cur = self._conn.execute(
                """
                INSERT INTO memories(content, kind, source, profile, session_id, tags_json, metadata_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (content, kind or "note", source or "manual", self._profile, session_id or self._session_id, _json_dumps(tags_list), _json_dumps(metadata_obj), now, now),
            )
            memory_id = int(cur.lastrowid)
            self._conn.execute(
                "INSERT INTO memory_vec(rowid, embedding) VALUES (?, ?)",
                (memory_id, self._serialize(content)),
            )
            self._conn.commit()
            return memory_id

    def _row_to_dict(self, row: sqlite3.Row, distance: Optional[float] = None) -> Dict[str, Any]:
        item = {
            "id": int(row["id"]),
            "content": row["content"],
            "kind": row["kind"],
            "source": row["source"],
            "profile": row["profile"],
            "session_id": row["session_id"],
            "tags": json.loads(row["tags_json"] or "[]"),
            "metadata": json.loads(row["metadata_json"] or "{}"),
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }
        if distance is not None:
            item["distance"] = float(distance)
        return item

    def _search(self, query: str, *, limit: int = 5, kind: Optional[str] = None) -> List[Dict[str, Any]]:
        if not self._conn:
            return []
        query = (query or "").strip()
        if not query:
            return []
        limit = max(1, min(int(limit or self._top_k), 50))
        params: List[Any] = [self._serialize(query), limit]
        kind_clause = ""
        if kind:
            kind_clause = " AND m.kind = ?"
            params.append(kind)
        sql = f"""
            SELECT m.*, v.distance
            FROM memory_vec v
            JOIN memories m ON m.id = v.rowid
            WHERE v.embedding MATCH ? AND k = ?
              AND m.deleted_at IS NULL
              AND m.profile = ?
              {kind_clause}
            ORDER BY v.distance
        """
        # profile must come before optional kind in SQL order
        params = [self._serialize(query), limit, self._profile] + ([kind] if kind else [])
        with self._lock:
            rows = self._conn.execute(sql, tuple(params)).fetchall()
        return [self._row_to_dict(row, row["distance"]) for row in rows]

    def _list(self, *, limit: int = 20, kind: Optional[str] = None) -> List[Dict[str, Any]]:
        if not self._conn:
            return []
        limit = max(1, min(int(limit or 20), 100))
        params: List[Any] = [self._profile]
        kind_clause = ""
        if kind:
            kind_clause = " AND kind = ?"
            params.append(kind)
        params.append(limit)
        with self._lock:
            rows = self._conn.execute(
                f"""
                SELECT * FROM memories
                WHERE deleted_at IS NULL AND profile = ? {kind_clause}
                ORDER BY id DESC LIMIT ?
                """,
                tuple(params),
            ).fetchall()
        return [self._row_to_dict(row) for row in rows]

    def _forget(self, memory_id: int) -> bool:
        if not self._conn:
            return False
        now = _utc_now()
        with self._lock:
            cur = self._conn.execute(
                "UPDATE memories SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL",
                (now, now, memory_id),
            )
            self._conn.commit()
        return cur.rowcount > 0


def register(ctx) -> None:
    ctx.register_memory_provider(SQLiteVecMemoryProvider())
