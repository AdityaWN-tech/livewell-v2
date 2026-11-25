"""Approved-content ingestion and retrieval (T-AGT-03, D-94).

catalog (content_items) -> ingest (approved only) -> chunks -> Embedder ->
VectorIndex (approved only) -> ContentRetriever (re-checks live status).
"""

from livewell_agents.content.catalog import ContentCatalog, StatusLookup
from livewell_agents.content.embedding import Embedder, HashingEmbedder, make_embedder
from livewell_agents.content.index import LocalVectorIndex, UnapprovedContentError, VectorIndex
from livewell_agents.content.ingest import IngestReport, ingest
from livewell_agents.content.models import Chunk, ContentItem, Passage
from livewell_agents.content.retriever import ContentRetriever

__all__ = [
    "Chunk",
    "ContentCatalog",
    "ContentItem",
    "ContentRetriever",
    "Embedder",
    "HashingEmbedder",
    "IngestReport",
    "LocalVectorIndex",
    "Passage",
    "StatusLookup",
    "UnapprovedContentError",
    "VectorIndex",
    "ingest",
    "make_embedder",
]
