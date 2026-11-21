"""Every kind of message we build validates against packages/schemas."""

import json

import jsonschema
import pytest

from livewell_agents.safety.templates import safety_message


@pytest.fixture(scope="module")
def schema(schema_path):
    s = json.loads(schema_path.read_text())
    jsonschema.Draft202012Validator.check_schema(s)
    return s


@pytest.mark.parametrize(
    "category", ["emergency", "crisis", "disordered_eating", "medication", "pregnancy_complex"]
)
@pytest.mark.parametrize("region", ["US", "IN", None])
def test_templates_validate(engine, schema, category, region):
    msg = safety_message(category, engine.contacts_for(region))
    jsonschema.validate(msg.model_dump(mode="json"), schema)


def test_fallback_validates(fallback, schema):
    jsonschema.validate(fallback.message(["safety_pre"]).model_dump(mode="json"), schema)


def test_schema_rejects_portal_card(fallback, schema):
    data = fallback.message([]).model_dump(mode="json")
    data["portal_card"] = {"offer": "x"}
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(data, schema)
