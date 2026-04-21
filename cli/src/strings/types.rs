/// AST types for the localization schema.
///
/// Types are inferred from the JSON shape:
/// - `"key": "value"` → `Plain`
/// - `"key": "Hello, {name}"` → `Template` (params extracted from braces)
/// - `"key(plural)": { "one": "...", "other": "..." }` → `Plural`
/// - `"key(gender)": { "male": "...", "female": "...", "other": "..." }` → `Gendered`
/// - `"key": [...]` → `List`
/// - `"key": { ... }` → `Group` (nested namespace)
/// - `"key": "@:other.key"` → `Reference`

/// A single localization file parsed into a tree.
#[derive(Debug, Clone)]
pub struct LocaleFile {
    pub locale: String,
    pub root: Group,
}

/// A namespace containing named entries.
#[derive(Debug, Clone)]
pub struct Group {
    pub entries: Vec<Entry>,
}

/// A named entry in a group.
#[derive(Debug, Clone)]
pub struct Entry {
    pub key: String,
    pub value: Value,
}

/// The value of a localization entry.
#[derive(Debug, Clone)]
pub enum Value {
    /// Plain string, no parameters.
    Plain(String),

    /// String with `{param}` placeholders.
    Template(TemplateValue),

    /// Plural variants keyed by CLDR category.
    Plural(PluralValue),

    /// Gender variants.
    Gendered(GenderedValue),

    /// Ordered list of values.
    List(ListValue),

    /// Nested namespace.
    Group(Group),

    /// Reference to another key: `"@:some.other.key"`.
    Reference(String),
}

#[derive(Debug, Clone)]
pub struct TemplateValue {
    pub raw: String,
    /// Named parameters (excludes `n` — that's tracked by `has_n`).
    pub params: Vec<String>,
    /// Whether this template contains `{n}` (the integer placeholder).
    pub has_n: bool,
}

#[derive(Debug, Clone)]
pub struct PluralValue {
    /// Each variant can be a plain string or a template.
    pub zero: Option<StringOrTemplate>,
    pub one: Option<StringOrTemplate>,
    pub two: Option<StringOrTemplate>,
    pub few: Option<StringOrTemplate>,
    pub many: Option<StringOrTemplate>,
    pub other: StringOrTemplate,
}

#[derive(Debug, Clone)]
pub struct GenderedValue {
    pub male: Option<StringOrTemplate>,
    pub female: Option<StringOrTemplate>,
    pub other: StringOrTemplate,
}

#[derive(Debug, Clone)]
pub struct ListValue {
    pub items: Vec<Value>,
}

/// A string that may or may not contain template parameters.
#[derive(Debug, Clone)]
pub enum StringOrTemplate {
    Plain(String),
    Template(TemplateValue),
}

impl StringOrTemplate {
    /// Collect all parameter names from this variant (excludes `n`).
    pub fn params(&self) -> &[String] {
        match self {
            StringOrTemplate::Plain(_) => &[],
            StringOrTemplate::Template(t) => &t.params,
        }
    }

    /// Whether this variant uses `{n}`.
    pub fn has_n(&self) -> bool {
        match self {
            StringOrTemplate::Plain(_) => false,
            StringOrTemplate::Template(t) => t.has_n,
        }
    }
}

impl PluralValue {
    /// Union of all named parameter names across variants.
    pub fn all_params(&self) -> Vec<String> {
        let mut params = Vec::new();
        for variant in self.variants() {
            for p in variant.params() {
                if !params.contains(p) {
                    params.push(p.clone());
                }
            }
        }
        params
    }

    /// Whether any variant uses `{n}`.
    pub fn has_n(&self) -> bool {
        self.variants().iter().any(|v| v.has_n())
    }

    fn variants(&self) -> Vec<&StringOrTemplate> {
        let mut v = Vec::new();
        if let Some(ref s) = self.zero { v.push(s); }
        if let Some(ref s) = self.one { v.push(s); }
        if let Some(ref s) = self.two { v.push(s); }
        if let Some(ref s) = self.few { v.push(s); }
        if let Some(ref s) = self.many { v.push(s); }
        v.push(&self.other);
        v
    }
}

impl GenderedValue {
    /// Union of all named parameter names across variants.
    pub fn all_params(&self) -> Vec<String> {
        let mut params = Vec::new();
        for variant in self.variants() {
            for p in variant.params() {
                if !params.contains(p) {
                    params.push(p.clone());
                }
            }
        }
        params
    }

    /// Whether any variant uses `{n}`.
    pub fn has_n(&self) -> bool {
        self.variants().iter().any(|v| v.has_n())
    }

    fn variants(&self) -> Vec<&StringOrTemplate> {
        let mut v = Vec::new();
        if let Some(ref s) = self.male { v.push(s); }
        if let Some(ref s) = self.female { v.push(s); }
        v.push(&self.other);
        v
    }
}
