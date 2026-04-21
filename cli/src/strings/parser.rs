use serde_json::Value as Json;
use std::fs;
use std::path::Path;

use super::types::*;

/// Parse a localization JSON file into a `LocaleFile`.
///
/// The locale is inferred from the filename (e.g. `en.json` → `"en"`).
pub fn parse_file(path: &Path) -> Result<LocaleFile, String> {
    let locale = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("en")
        .to_string();

    let content = fs::read_to_string(path)
        .map_err(|e| format!("Failed to read {}: {}", path.display(), e))?;

    let json: Json = serde_json::from_str(&content)
        .map_err(|e| format!("Failed to parse {}: {}", path.display(), e))?;

    let root = match json {
        Json::Object(map) => parse_group(&map),
        _ => return Err("Root must be a JSON object".into()),
    };

    Ok(LocaleFile { locale, root })
}

pub fn parse_group(map: &serde_json::Map<String, Json>) -> Group {
    let mut entries = Vec::new();

    for (raw_key, json_value) in map {
        // Check for (plural) or (gender) suffix
        if let Some(base_key) = strip_suffix(raw_key, "(plural)") {
            let value = parse_plural(json_value);
            entries.push(Entry { key: base_key, value });
        } else if let Some(base_key) = strip_suffix(raw_key, "(gender)") {
            let value = parse_gendered(json_value);
            entries.push(Entry { key: base_key, value });
        } else {
            let value = parse_value(json_value);
            entries.push(Entry { key: raw_key.clone(), value });
        }
    }

    Group { entries }
}

fn parse_value(json: &Json) -> Value {
    match json {
        Json::String(s) => parse_string_value(s),
        Json::Array(arr) => parse_list(arr),
        Json::Object(map) => Value::Group(parse_group(map)),
        _ => Value::Plain(json.to_string()),
    }
}

fn parse_string_value(s: &str) -> Value {
    // Reference: "@:some.key.path"
    if let Some(path) = s.strip_prefix("@:") {
        return Value::Reference(path.to_string());
    }

    // Template: contains {param} placeholders
    let (params, has_n) = extract_params(s);
    if params.is_empty() && !has_n {
        Value::Plain(s.to_string())
    } else {
        Value::Template(TemplateValue {
            raw: s.to_string(),
            params,
            has_n,
        })
    }
}

fn parse_list(arr: &[Json]) -> Value {
    let items = arr.iter().map(parse_value).collect();
    Value::List(ListValue { items })
}

fn parse_plural(json: &Json) -> Value {
    let map = match json {
        Json::Object(map) => map,
        _ => return Value::Plain(json.to_string()),
    };

    Value::Plural(PluralValue {
        zero: map.get("zero").map(|v| parse_string_or_template(v)),
        one: map.get("one").map(|v| parse_string_or_template(v)),
        two: map.get("two").map(|v| parse_string_or_template(v)),
        few: map.get("few").map(|v| parse_string_or_template(v)),
        many: map.get("many").map(|v| parse_string_or_template(v)),
        other: map
            .get("other")
            .map(|v| parse_string_or_template(v))
            .unwrap_or(StringOrTemplate::Plain("".into())),
    })
}

fn parse_gendered(json: &Json) -> Value {
    let map = match json {
        Json::Object(map) => map,
        _ => return Value::Plain(json.to_string()),
    };

    Value::Gendered(GenderedValue {
        male: map.get("male").map(|v| parse_string_or_template(v)),
        female: map.get("female").map(|v| parse_string_or_template(v)),
        other: map
            .get("other")
            .map(|v| parse_string_or_template(v))
            .unwrap_or(StringOrTemplate::Plain("".into())),
    })
}

fn parse_string_or_template(json: &Json) -> StringOrTemplate {
    let s = match json {
        Json::String(s) => s.as_str(),
        _ => return StringOrTemplate::Plain(json.to_string()),
    };

    let (params, has_n) = extract_params(s);
    if params.is_empty() && !has_n {
        StringOrTemplate::Plain(s.to_string())
    } else {
        StringOrTemplate::Template(TemplateValue {
            raw: s.to_string(),
            params,
            has_n,
        })
    }
}

/// Extract `{param}` names from a string, ignoring BetterText style tokens.
///
/// Returns `(named_params, has_n)` where:
/// - `named_params` are regular string parameters (e.g. `{name}`, `{folder}`)
/// - `has_n` is true if the string contains `{n}` (the integer placeholder)
///
/// `{n}` is a recognized keyword meaning "integer value". It's excluded from
/// the named params list and tracked separately.
///
/// BetterText groups like `{bold,red My text}` contain spaces/commas and are
/// NOT extracted as params — they're rendered at runtime by the BetterText parser.
fn extract_params(s: &str) -> (Vec<String>, bool) {
    let mut params = Vec::new();
    let mut has_n = false;
    let mut chars = s.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '\\' {
            chars.next();
        } else if c == '{' {
            let mut content = String::new();
            for inner in chars.by_ref() {
                if inner == '}' {
                    break;
                }
                content.push(inner);
            }
            let trimmed = content.trim();
            if !trimmed.is_empty()
                && !trimmed.contains(' ')
                && !trimmed.contains(',')
                && trimmed.chars().all(|c| c.is_alphanumeric() || c == '_')
            {
                if trimmed == "n" {
                    has_n = true;
                } else if !params.contains(&trimmed.to_string()) {
                    params.push(trimmed.to_string());
                }
            }
        }
    }

    (params, has_n)
}

fn strip_suffix(key: &str, suffix: &str) -> Option<String> {
    key.strip_suffix(suffix).map(|s| s.trim().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_params_simple() {
        let (params, has_n) = extract_params("Hello, {name}");
        assert_eq!(params, vec!["name"]);
        assert!(!has_n);
    }

    #[test]
    fn test_extract_params_multiple() {
        let (params, has_n) = extract_params("{greeting}, {name}! You have {count} items.");
        assert_eq!(params, vec!["greeting", "name", "count"]);
        assert!(!has_n);
    }

    #[test]
    fn test_extract_params_no_params() {
        let (params, has_n) = extract_params("Just a plain string");
        assert!(params.is_empty());
        assert!(!has_n);
    }

    #[test]
    fn test_extract_params_ignores_bettertext() {
        let (params, has_n) = extract_params("Welcome to {bold Forge}, {name}");
        assert_eq!(params, vec!["name"]);
        assert!(!has_n);
    }

    #[test]
    fn test_extract_params_ignores_multi_style() {
        let (params, has_n) = extract_params("{red,bold Important}");
        assert!(params.is_empty());
        assert!(!has_n);
    }

    #[test]
    fn test_extract_params_deduplicates() {
        let (params, has_n) = extract_params("{name} and {name} again");
        assert_eq!(params, vec!["name"]);
        assert!(!has_n);
    }

    #[test]
    fn test_extract_params_escaped_brace() {
        let (params, has_n) = extract_params("Price: \\{99\\} and {name}");
        assert_eq!(params, vec!["name"]);
        assert!(!has_n);
    }

    #[test]
    fn test_extract_params_n_keyword() {
        let (params, has_n) = extract_params("{n} items in {folder}");
        assert_eq!(params, vec!["folder"]);
        assert!(has_n);
    }

    #[test]
    fn test_extract_params_n_alone() {
        let (params, has_n) = extract_params("{n} followers");
        assert!(params.is_empty());
        assert!(has_n);
    }

    #[test]
    fn test_parse_plain_string() {
        let json: Json = serde_json::json!("Hello");
        match parse_value(&json) {
            Value::Plain(s) => assert_eq!(s, "Hello"),
            _ => panic!("Expected Plain"),
        }
    }

    #[test]
    fn test_parse_template() {
        let json: Json = serde_json::json!("Hello, {name}");
        match parse_value(&json) {
            Value::Template(t) => {
                assert_eq!(t.raw, "Hello, {name}");
                assert_eq!(t.params, vec!["name"]);
            }
            _ => panic!("Expected Template"),
        }
    }

    #[test]
    fn test_parse_reference() {
        let json: Json = serde_json::json!("@:common.save");
        match parse_value(&json) {
            Value::Reference(path) => assert_eq!(path, "common.save"),
            _ => panic!("Expected Reference"),
        }
    }

    #[test]
    fn test_parse_list() {
        let json: Json = serde_json::json!(["First", "Second", "Third"]);
        match parse_value(&json) {
            Value::List(list) => assert_eq!(list.items.len(), 3),
            _ => panic!("Expected List"),
        }
    }

    #[test]
    fn test_parse_group() {
        let json: Json = serde_json::json!({
            "title": "Settings",
            "subtitle": "Manage preferences"
        });
        match parse_value(&json) {
            Value::Group(g) => assert_eq!(g.entries.len(), 2),
            _ => panic!("Expected Group"),
        }
    }

    #[test]
    fn test_parse_plural_suffix() {
        let json: Json = serde_json::json!({
            "itemCount(plural)": {
                "one": "{count} item",
                "other": "{count} items"
            }
        });
        let map = json.as_object().unwrap();
        let group = parse_group(map);
        assert_eq!(group.entries.len(), 1);
        assert_eq!(group.entries[0].key, "itemCount");
        assert!(matches!(group.entries[0].value, Value::Plural(_)));
    }

    #[test]
    fn test_parse_gender_suffix() {
        let json: Json = serde_json::json!({
            "greeting(gender)": {
                "male": "Welcome, sir",
                "female": "Welcome, madam",
                "other": "Welcome"
            }
        });
        let map = json.as_object().unwrap();
        let group = parse_group(map);
        assert_eq!(group.entries.len(), 1);
        assert_eq!(group.entries[0].key, "greeting");
        assert!(matches!(group.entries[0].value, Value::Gendered(_)));
    }

    #[test]
    fn test_nested_groups() {
        let json: Json = serde_json::json!({
            "profile": {
                "stats": {
                    "followers": "{count} followers"
                }
            }
        });
        let map = json.as_object().unwrap();
        let group = parse_group(map);
        match &group.entries[0].value {
            Value::Group(inner) => match &inner.entries[0].value {
                Value::Group(deepest) => {
                    assert_eq!(deepest.entries[0].key, "followers");
                    assert!(matches!(deepest.entries[0].value, Value::Template(_)));
                }
                _ => panic!("Expected nested Group"),
            },
            _ => panic!("Expected Group"),
        }
    }

    #[test]
    fn test_list_of_objects() {
        let json: Json = serde_json::json!({
            "steps": [
                { "title": "Welcome", "body": "Get started" },
                { "title": "Done", "body": "All set" }
            ]
        });
        let map = json.as_object().unwrap();
        let group = parse_group(map);
        match &group.entries[0].value {
            Value::List(list) => {
                assert_eq!(list.items.len(), 2);
                assert!(matches!(list.items[0], Value::Group(_)));
            }
            _ => panic!("Expected List"),
        }
    }
}
