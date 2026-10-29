//! Log records on stdout, as docs/logging.md describes them: one JSON object per line, next to the other
//! events, `{"event":"log","time":...,"level":...,"source":"tor","target":...,"msg":...}` plus the
//! fields of the record.
//!
//! Every line on stdout goes through [`write_line`], which holds the stdout lock for the whole line, so a
//! log record never cuts into an event written by another thread.

use std::fmt::{Debug, Write as _};
use std::io::Write as _;
use std::time::{SystemTime, UNIX_EPOCH};

use serde_json::Value;

use tracing::field::{Field, Visit};
use tracing::{Event, Subscriber};
use tracing_subscriber::EnvFilter;
use tracing_subscriber::layer::{Context, Layer, SubscriberExt};
use tracing_subscriber::util::SubscriberInitExt;

/// The `source` of every record this process writes.
pub const SOURCE: &str = "tor";

/// Crates that log for every stream or cell: one step quieter than the chosen level at `debug` and
/// `info`, so a debug log stays readable while traffic flows. `trace` keeps them all.
const NOISY_TARGETS: [&str; 2] = ["tor_proto", "tor_cell"];

/// Keys of the record itself; an event field with one of these names is written as `name_`.
const RESERVED_KEYS: [&str; 8] = [
    "event", "time", "level", "source", "target", "msg", "caller", "stack",
];

/// How much is logged, from most to least.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord)]
pub enum Level {
    Trace,
    Debug,
    Info,
    Warn,

    /// What a release build keeps (with `fatal`).
    #[default]
    Error,

    /// Panics only.
    Fatal,
}

impl Level {
    /// The level named `name` (`trace` `debug` `info` `warn` `error` `fatal`).
    pub fn parse(name: &str) -> Option<Level> {
        match name {
            "trace" => Some(Level::Trace),
            "debug" => Some(Level::Debug),
            "info" => Some(Level::Info),
            "warn" => Some(Level::Warn),
            "error" => Some(Level::Error),
            "fatal" => Some(Level::Fatal),
            _ => None,
        }
    }

    /// The name written in the `level` key.
    pub fn name(self) -> &'static str {
        match self {
            Level::Trace => "trace",
            Level::Debug => "debug",
            Level::Info => "info",
            Level::Warn => "warn",
            Level::Error => "error",
            Level::Fatal => "fatal",
        }
    }

    /// The level of a `tracing` event.
    pub fn from_tracing(level: &tracing::Level) -> Level {
        match *level {
            tracing::Level::TRACE => Level::Trace,
            tracing::Level::DEBUG => Level::Debug,
            tracing::Level::INFO => Level::Info,
            tracing::Level::WARN => Level::Warn,
            tracing::Level::ERROR => Level::Error,
        }
    }

    /// The `EnvFilter` directives for this level (`RUST_LOG` replaces them when it is set).
    pub fn filter_directives(self) -> String {
        let (everything, noisy) = match self {
            Level::Trace => ("trace", None),
            Level::Debug => ("debug", Some("info")),
            Level::Info => ("info", Some("warn")),
            Level::Warn => ("warn", None),
            Level::Error => ("error", None),
            // Panics are written by the panic hook, not through `tracing`.
            Level::Fatal => ("off", None),
        };

        let mut directives = everything.to_string();
        if let Some(noisy_level) = noisy {
            for target in NOISY_TARGETS {
                let _ = write!(directives, ",{target}={noisy_level}");
            }
        }

        directives
    }
}

/// One log record.
#[derive(Clone, Debug, PartialEq)]
pub struct Record {
    pub level: Level,

    /// The Rust module that logged it.
    pub target: Option<String>,

    pub msg: String,

    /// The other keys (`op`, `code`, `err`, `notify`, ...), in the order they were given.
    pub fields: Vec<(String, Value)>,

    /// `file:line` where it was logged.
    pub caller: Option<String>,

    /// The stack trace (panics).
    pub stack: Option<String>,
}

impl Record {
    /// A record with only a level and a message.
    pub fn new(level: Level, msg: impl Into<String>) -> Record {
        Record {
            level,
            target: None,
            msg: msg.into(),
            fields: Vec::new(),
            caller: None,
            stack: None,
        }
    }

    /// The record with one more field.
    pub fn with(mut self, key: &str, value: impl Into<Value>) -> Record {
        self.fields.push((key.to_string(), value.into()));
        self
    }

    /// The stdout line for this record (without the newline), stamped with `time`.
    pub fn to_line(&self, time: SystemTime) -> String {
        let mut line = String::with_capacity(128 + self.msg.len());

        line.push_str(r#"{"event":"log""#);
        push_key(&mut line, "time", &Value::String(rfc3339_millis(time)));
        push_key(&mut line, "level", &Value::from(self.level.name()));
        push_key(&mut line, "source", &Value::from(SOURCE));

        if let Some(target) = &self.target {
            push_key(&mut line, "target", &Value::from(target.as_str()));
        }

        push_key(&mut line, "msg", &Value::from(self.msg.as_str()));
        for (key, value) in &self.fields {
            if RESERVED_KEYS.contains(&key.as_str()) {
                push_key(&mut line, &format!("{key}_"), value);
            } else {
                push_key(&mut line, key, value);
            }
        }

        if let Some(caller) = &self.caller {
            push_key(&mut line, "caller", &Value::from(caller.as_str()));
        }

        if let Some(stack) = &self.stack {
            push_key(&mut line, "stack", &Value::from(stack.as_str()));
        }

        line.push('}');
        line
    }

    /// Writes the record to stdout, now.
    pub fn write(&self) {
        write_line(&self.to_line(SystemTime::now()));
    }
}

/// Appends `,"key":value` (both JSON-escaped, so a newline in a message stays on this line).
fn push_key(line: &mut String, key: &str, value: &Value) {
    let _ = write!(line, ",{}:{value}", Value::from(key));
}

/// Writes one line to stdout and flushes it. The stdout lock is held for the whole line, so lines from
/// different threads never mix; the core reads stdout line by line.
pub fn write_line(line: &str) {
    let mut stdout = std::io::stdout().lock();
    let _ = stdout.write_all(line.as_bytes());
    let _ = stdout.write_all(b"\n");
    let _ = stdout.flush();
}

/// `time` as RFC 3339 in UTC with milliseconds, e.g. `2026-10-29T01:02:03.456Z`.
pub fn rfc3339_millis(time: SystemTime) -> String {
    let since_epoch = time.duration_since(UNIX_EPOCH).unwrap_or_default();
    let seconds = since_epoch.as_secs();
    let millis = since_epoch.subsec_millis();
    // Days since 1970 fit an i64 for any clock this runs on; saturate rather than wrap if one ever does not.
    let (year, month, day) = civil_from_days(i64::try_from(seconds / 86_400).unwrap_or(i64::MAX));
    let second_of_day = seconds % 86_400;

    format!(
        "{year:04}-{month:02}-{day:02}T{:02}:{:02}:{:02}.{millis:03}Z",
        second_of_day / 3600,
        second_of_day % 3600 / 60,
        second_of_day % 60,
    )
}

/// The (year, month, day) of a day counted from 1970-01-01 (Howard Hinnant's `civil_from_days`).
fn civil_from_days(days: i64) -> (i64, i64, i64) {
    let shifted = days + 719_468;
    let era = shifted.div_euclid(146_097);
    let day_of_era = shifted.rem_euclid(146_097);
    let year_of_era =
        (day_of_era - day_of_era / 1460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let month_index = (5 * day_of_year + 2) / 153;
    let day = day_of_year - (153 * month_index + 2) / 5 + 1;

    let month = if month_index < 10 {
        month_index + 3
    } else {
        month_index - 9
    };

    let year = year_of_era + era * 400 + i64::from(month <= 2);
    (year, month, day)
}

/// `file:line`, with a dependency's path cut to its crate folder (`tor-proto-0.47.0/src/...`): the
/// rest is the build machine's cargo folder.
pub fn caller(file: &str, line: u32) -> String {
    let file = file.replace('\\', "/");
    let short = match file.rfind("/src/") {
        Some(src_index) => match file[..src_index].rfind('/') {
            Some(crate_start) => &file[crate_start + 1..],
            None => file.as_str(),
        },

        None => file.as_str(),
    };

    format!("{short}:{line}")
}

/// Collects the message and the other fields of a `tracing` event.
#[derive(Default)]
struct FieldCollector {
    msg: Option<String>,
    fields: Vec<(String, Value)>,
}

impl FieldCollector {
    fn put(&mut self, field: &Field, value: Value) {
        match field.name() {
            "message" => {
                self.msg = Some(match value {
                    Value::String(text) => text,
                    other => other.to_string(),
                });
            }

            // Metadata of records bridged from the `log` crate, already in the record's own keys.
            name if name.starts_with("log.") => {}
            name => self.fields.push((name.to_string(), value)),
        }
    }
}

impl Visit for FieldCollector {
    fn record_f64(&mut self, field: &Field, value: f64) {
        self.put(field, Value::from(value));
    }

    fn record_i64(&mut self, field: &Field, value: i64) {
        self.put(field, Value::from(value));
    }

    fn record_u64(&mut self, field: &Field, value: u64) {
        self.put(field, Value::from(value));
    }

    fn record_bool(&mut self, field: &Field, value: bool) {
        self.put(field, Value::from(value));
    }

    fn record_str(&mut self, field: &Field, value: &str) {
        self.put(field, Value::from(value));
    }

    fn record_error(&mut self, field: &Field, value: &(dyn std::error::Error + 'static)) {
        // The whole chain, as anyhow's `{:#}` writes it.
        let mut chain = value.to_string();
        let mut source = value.source();
        while let Some(cause) = source {
            let _ = write!(chain, ": {cause}");
            source = cause.source();
        }

        self.put(field, Value::from(chain));
    }

    fn record_debug(&mut self, field: &Field, value: &dyn Debug) {
        self.put(field, Value::from(format!("{value:?}")));
    }
}

/// The `tracing` layer that writes each event as a record on stdout. The filter in front of it drops
/// events below the level before they are formatted.
pub struct JsonLayer {
    /// Add `caller` (debug and trace).
    with_caller: bool,
}

impl JsonLayer {
    /// The layer for the chosen level.
    pub fn new(level: Level) -> JsonLayer {
        JsonLayer {
            with_caller: level <= Level::Debug,
        }
    }

    /// The record for one event.
    pub fn record(&self, event: &Event<'_>) -> Record {
        let metadata = event.metadata();
        let mut collector = FieldCollector::default();
        event.record(&mut collector);

        let caller = match (self.with_caller, metadata.file(), metadata.line()) {
            (true, Some(file), Some(line)) => Some(caller(file, line)),
            _ => None,
        };

        Record {
            level: Level::from_tracing(metadata.level()),
            target: Some(metadata.target().to_string()),
            msg: collector.msg.unwrap_or_default(),
            fields: collector.fields,
            caller,
            stack: None,
        }
    }
}

impl<S: Subscriber> Layer<S> for JsonLayer {
    fn on_event(&self, event: &Event<'_>, _context: Context<'_, S>) {
        self.record(event).write();
    }
}

/// Sends `tracing` (Arti's logs and ours) to stdout as records at `level`; `RUST_LOG`, when it is set
/// and valid, replaces the level's filter.
pub fn init(level: Level) {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(level.filter_directives()));

    let _ = tracing_subscriber::registry()
        .with(filter)
        .with(JsonLayer::new(level))
        .try_init();
}

/// The `fatal` record for a panic.
pub fn panic_record(
    msg: &str,
    location: Option<String>,
    thread: Option<&str>,
    stack: String,
) -> Record {
    let mut record = Record::new(Level::Fatal, msg).with("notify", true);
    if let Some(thread_name) = thread {
        record = record.with("thread", thread_name);
    }

    record.caller = location;
    record.stack = Some(stack);
    record
}

/// Replaces the default panic hook (which prints to stderr) with one that writes a `fatal` record to
/// stdout and then calls `exit`.
pub fn install_panic_hook(exit: fn()) {
    std::panic::set_hook(Box::new(move |info| {
        let msg = info.payload_as_str().unwrap_or("panic");
        let location = info
            .location()
            .map(|location| caller(location.file(), location.line()));

        let current = std::thread::current();
        let stack = std::backtrace::Backtrace::force_capture().to_string();
        panic_record(msg, location, current.name(), stack).write();
        exit();
    }));
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::*;

    fn parse_line(line: &str) -> serde_json::Map<String, Value> {
        assert!(!line.contains('\n'), "not one line: {line}");
        match serde_json::from_str(line).unwrap() {
            Value::Object(object) => object,
            other => panic!("not an object: {other}"),
        }
    }

    #[test]
    fn level_names_round_trip() {
        for name in ["trace", "debug", "info", "warn", "error", "fatal"] {
            assert_eq!(Level::parse(name).unwrap().name(), name);
        }

        assert_eq!(Level::parse("WARN"), None);
        assert_eq!(Level::parse("warning"), None);
        assert_eq!(Level::default(), Level::Error);
    }

    #[test]
    fn maps_tracing_levels() {
        assert_eq!(Level::from_tracing(&tracing::Level::ERROR), Level::Error);
        assert_eq!(Level::from_tracing(&tracing::Level::WARN), Level::Warn);
        assert_eq!(Level::from_tracing(&tracing::Level::INFO), Level::Info);
        assert_eq!(Level::from_tracing(&tracing::Level::DEBUG), Level::Debug);
        assert_eq!(Level::from_tracing(&tracing::Level::TRACE), Level::Trace);
    }

    #[test]
    fn filter_keeps_noisy_crates_quieter() {
        assert_eq!(Level::Trace.filter_directives(), "trace");
        assert_eq!(
            Level::Debug.filter_directives(),
            "debug,tor_proto=info,tor_cell=info"
        );

        assert_eq!(
            Level::Info.filter_directives(),
            "info,tor_proto=warn,tor_cell=warn"
        );

        assert_eq!(Level::Error.filter_directives(), "error");
        assert_eq!(Level::Fatal.filter_directives(), "off");

        for level in [Level::Trace, Level::Debug, Level::Info, Level::Error] {
            EnvFilter::try_new(level.filter_directives()).unwrap();
        }
    }

    #[test]
    fn formats_time() {
        assert_eq!(rfc3339_millis(UNIX_EPOCH), "1970-01-01T00:00:00.000Z");

        let time = UNIX_EPOCH + Duration::from_millis(1_793_235_723_456);
        assert_eq!(rfc3339_millis(time), "2026-10-29T01:02:03.456Z");

        let leap_day = UNIX_EPOCH + Duration::from_secs(951_782_400);
        assert_eq!(rfc3339_millis(leap_day), "2000-02-29T00:00:00.000Z");
    }

    #[test]
    fn record_has_every_key() {
        let mut record = Record::new(Level::Warn, "stream failed")
            .with("op", "connect")
            .with("code", "TIMEOUT")
            .with("count", 3)
            .with("notify", false);

        record.target = Some("omnitun_tor".into());
        record.caller = Some("src/main.rs:12".into());

        let line = record.to_line(UNIX_EPOCH);
        assert!(line.starts_with(r#"{"event":"log","time":"1970-01-01T00:00:00.000Z","level":"warn","source":"tor","target":"omnitun_tor","msg":"stream failed""#));

        let object = parse_line(&line);
        assert_eq!(object["op"], "connect");
        assert_eq!(object["code"], "TIMEOUT");
        assert_eq!(object["count"], 3);
        assert_eq!(object["notify"], false);
        assert_eq!(object["caller"], "src/main.rs:12");
        assert!(!object.contains_key("stack"));
    }

    #[test]
    fn record_without_optional_keys() {
        let object = parse_line(&Record::new(Level::Error, "x").to_line(UNIX_EPOCH));
        let mut keys: Vec<&str> = object.keys().map(String::as_str).collect();
        keys.sort_unstable();
        assert_eq!(keys, ["event", "level", "msg", "source", "time"]);
    }

    #[test]
    fn escapes_into_one_line() {
        let msg = "said \"no\"\nthen\r\n\ttab \\ and \u{1} and ünï";
        let record = Record::new(Level::Info, msg).with("err", "line one\nline two");
        let object = parse_line(&record.to_line(SystemTime::now()));
        assert_eq!(object["msg"], msg);
        assert_eq!(object["err"], "line one\nline two");
    }

    #[test]
    fn field_cannot_replace_a_record_key() {
        let record = Record::new(Level::Info, "real")
            .with("msg", "fake")
            .with("level", "fatal");

        let object = parse_line(&record.to_line(UNIX_EPOCH));
        assert_eq!(object["msg"], "real");
        assert_eq!(object["level"], "info");
        assert_eq!(object["msg_"], "fake");
        assert_eq!(object["level_"], "fatal");
    }

    #[test]
    fn panic_record_notifies() {
        let record = panic_record(
            "boom",
            Some("src/main.rs:9".into()),
            Some("main"),
            "stack".into(),
        );

        let object = parse_line(&record.to_line(UNIX_EPOCH));
        assert_eq!(object["level"], "fatal");
        assert_eq!(object["msg"], "boom");
        assert_eq!(object["notify"], true);
        assert_eq!(object["caller"], "src/main.rs:9");
        assert_eq!(object["stack"], "stack");
        assert_eq!(object["thread"], "main");
    }

    #[test]
    fn shortens_dependency_paths() {
        assert_eq!(caller("src/main.rs", 4), "src/main.rs:4");
        assert_eq!(
            caller(
                r"C:\Users\me\.cargo\registry\src\index.crates.io-1\tor-proto-0.47.0\src\channel.rs",
                7
            ),
            "tor-proto-0.47.0/src/channel.rs:7"
        );

        assert_eq!(
            caller(
                "/home/me/.cargo/registry/src/index-1/tor-proto-0.47.0/src/client/mod.rs",
                7
            ),
            "tor-proto-0.47.0/src/client/mod.rs:7"
        );
    }

    /// A `tracing` event through the layer: message, typed fields and the level.
    #[test]
    fn layer_collects_event_fields() {
        use std::sync::{Arc, Mutex};

        /// Keeps the records instead of writing them.
        struct Capture {
            layer: JsonLayer,
            records: Arc<Mutex<Vec<Record>>>,
        }

        impl<S: Subscriber> Layer<S> for Capture {
            fn on_event(&self, event: &Event<'_>, _context: Context<'_, S>) {
                self.records.lock().unwrap().push(self.layer.record(event));
            }
        }

        let records = Arc::new(Mutex::new(Vec::new()));
        let subscriber = tracing_subscriber::registry().with(Capture {
            layer: JsonLayer::new(Level::Debug),
            records: records.clone(),
        });

        tracing::subscriber::with_default(subscriber, || {
            let error = std::io::Error::other("refused");
            tracing::warn!(
                op = "connect",
                notify = true,
                count = 2_u64,
                err = &error as &(dyn std::error::Error + 'static),
                "stream {} failed",
                7
            );
        });

        let records = records.lock().unwrap();
        let record = &records[0];
        assert_eq!(record.level, Level::Warn);
        assert_eq!(record.msg, "stream 7 failed");
        assert_eq!(
            record.target.as_deref(),
            Some("omnitun_tor::logging::tests")
        );

        assert!(
            record
                .caller
                .as_deref()
                .unwrap()
                .starts_with("src/logging.rs:")
        );

        let object = parse_line(&record.to_line(UNIX_EPOCH));
        assert_eq!(object["op"], "connect");
        assert_eq!(object["notify"], true);
        assert_eq!(object["count"], 2);
        assert_eq!(object["err"], "refused");
    }
}
