"""
URL fetch and readable text extraction for link capture.
"""

from __future__ import annotations

import ipaddress
import re
from dataclasses import dataclass
from html import unescape
from html.parser import HTMLParser
from urllib.parse import urlparse

import httpx


MIN_EXTRACTED_TEXT_LENGTH = 30
MAX_LINK_TEXT_LENGTH = 40_000
REQUEST_TIMEOUT_SECONDS = 10.0
USER_AGENT = "Plowth/0.1 link-ingest"


class LinkIngestError(ValueError):
    """Raised when a URL cannot be fetched or converted into study text."""


@dataclass(frozen=True)
class LinkExtraction:
    url: str
    title: str | None
    text: str
    metadata: dict


class _ReadableTextParser(HTMLParser):
    ignored_tags = {
        "script",
        "style",
        "noscript",
        "svg",
        "canvas",
        "nav",
        "footer",
        "form",
        "button",
    }

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._ignored_depth = 0
        self._in_title = False
        self._title_parts: list[str] = []
        self._text_parts: list[str] = []

    @property
    def title(self) -> str | None:
        title = _collapse_whitespace(" ".join(self._title_parts))
        return title or None

    @property
    def text(self) -> str:
        return _collapse_whitespace(" ".join(self._text_parts))

    def handle_starttag(self, tag: str, attrs) -> None:
        if tag == "title":
            self._in_title = True
        if tag in self.ignored_tags:
            self._ignored_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._in_title = False
        if tag in self.ignored_tags and self._ignored_depth:
            self._ignored_depth -= 1

    def handle_data(self, data: str) -> None:
        value = unescape(data).strip()
        if not value:
            return
        if self._in_title:
            self._title_parts.append(value)
            return
        if self._ignored_depth == 0:
            self._text_parts.append(value)


def _collapse_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def validate_link_url(url: str | None) -> str:
    value = (url or "").strip()
    if not value:
        raise LinkIngestError("URL is required for link capture.")
    if len(value) > 2000:
        raise LinkIngestError("URL is too long.")

    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"}:
        raise LinkIngestError("URL must start with http:// or https://.")
    if not parsed.hostname:
        raise LinkIngestError("URL must include a hostname.")

    hostname = parsed.hostname.lower()
    if hostname == "localhost" or hostname.endswith(".local"):
        raise LinkIngestError("Local network URLs are not supported.")

    try:
        address = ipaddress.ip_address(hostname)
    except ValueError:
        return value

    if (
        address.is_private
        or address.is_loopback
        or address.is_link_local
        or address.is_reserved
        or address.is_multicast
    ):
        raise LinkIngestError("Private network URLs are not supported.")

    return value


def extract_text_from_html(html_text: str, *, url: str) -> LinkExtraction:
    parser = _ReadableTextParser()
    try:
        parser.feed(html_text)
    except Exception as exc:
        raise LinkIngestError("The page content could not be parsed.") from exc

    text = parser.text
    if len(text) > MAX_LINK_TEXT_LENGTH:
        text = text[:MAX_LINK_TEXT_LENGTH].rstrip()
    if len(text) < MIN_EXTRACTED_TEXT_LENGTH:
        raise LinkIngestError("The page did not contain enough readable text.")

    return LinkExtraction(
        url=url,
        title=parser.title,
        text=text,
        metadata={
            "url": url,
            "extracted_length": len(text),
            "extraction_method": "html-parser-v1",
        },
    )


async def fetch_link_content(url: str) -> LinkExtraction:
    validated_url = validate_link_url(url)
    headers = {"User-Agent": USER_AGENT, "Accept": "text/html,text/plain;q=0.9,*/*;q=0.1"}

    try:
        async with httpx.AsyncClient(
            follow_redirects=True,
            timeout=REQUEST_TIMEOUT_SECONDS,
            headers=headers,
        ) as client:
            response = await client.get(validated_url)
            response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        raise LinkIngestError(
            f"The page returned HTTP {exc.response.status_code}."
        ) from exc
    except httpx.RequestError as exc:
        raise LinkIngestError("The page could not be reached.") from exc

    content_type = response.headers.get("content-type", "")
    if content_type and not (
        "text/html" in content_type or "text/plain" in content_type
    ):
        raise LinkIngestError("The page did not return readable text content.")

    extraction = extract_text_from_html(response.text, url=str(response.url))
    return LinkExtraction(
        url=extraction.url,
        title=extraction.title,
        text=extraction.text,
        metadata={**extraction.metadata, "content_type": content_type},
    )
