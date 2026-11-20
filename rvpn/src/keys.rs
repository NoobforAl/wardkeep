//! The client's identity key (`DIR/identity.key`) and the server's prekey bundle (`--bundle`).
//!
//! The key file is upstream's format (`IdentityKey::load` / `IdentityKey::save` in rvpn-core, the file
//! `rvpn-client keygen` writes), so a key can move between this client and upstream's. Neither the key nor
//! its path is ever logged or printed.

use std::fs::{self, OpenOptions};
use std::io::ErrorKind;
use std::path::{Path, PathBuf};

use rvpn_core::crypto::{IdentityKey, X3DHPublicBundle, verify_identity_x25519_signature};

/// The file name of the identity key in the data directory.
pub const IDENTITY_FILE: &str = "identity.key";

/// A bundle is a few hundred bytes of JSON; anything far larger is not one.
const MAX_BUNDLE_SIZE: u64 = 64 * 1024;

/// Why the identity key could not be had. The texts name no path.
#[derive(Debug)]
pub enum IdentityError {
    /// The file exists but is not a key. It is left alone: replacing it would change the client's identity.
    Corrupt,
    Io(ErrorKind),
}

impl std::fmt::Display for IdentityError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            IdentityError::Corrupt => f.write_str("the identity key file is not a valid key"),
            IdentityError::Io(kind) => {
                write!(f, "the identity key file could not be used ({kind:?})")
            }
        }
    }
}

fn io(err: &std::io::Error) -> IdentityError {
    IdentityError::Io(err.kind())
}

/// Creates `path` empty and readable by its owner only (0600 on unix; on Windows the data directory's
/// ACL, which is the user's own, applies).
fn create_private(path: &Path) -> std::io::Result<fs::File> {
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }

    options.open(path)
}

/// Writes a new key to `path` atomically: a temporary file next to it (created 0600 before any key byte
/// is in it), flushed, then renamed over `path`. A crash leaves either no key or a whole one.
fn save_new(key: &IdentityKey, path: &Path) -> Result<(), IdentityError> {
    let tmp: PathBuf = path.with_extension("key.tmp");
    match fs::remove_file(&tmp) {
        Ok(()) => {}
        Err(err) if err.kind() == ErrorKind::NotFound => {}
        Err(err) => return Err(io(&err)),
    }

    drop(create_private(&tmp).map_err(|err| io(&err))?);

    // `save` writes with fs::write, which truncates the file and keeps its 0600 mode.
    let written = key
        .save(&tmp)
        .map_err(|_| IdentityError::Io(ErrorKind::Other))
        .and_then(|()| {
            OpenOptions::new()
                .write(true)
                .open(&tmp)
                .and_then(|file| file.sync_all())
                .map_err(|err| io(&err))
        })
        .and_then(|()| fs::rename(&tmp, path).map_err(|err| io(&err)));

    if written.is_err() {
        let _ = fs::remove_file(&tmp);
    }

    written
}

/// Loads `DIR/identity.key`, or creates the directory and a new key when there is none.
pub fn load_or_create(dir: &Path) -> Result<IdentityKey, IdentityError> {
    let path = dir.join(IDENTITY_FILE);
    match fs::metadata(&path) {
        Ok(_) => {
            // rvpn-core turns an I/O error into "invalid key": open it first to tell the two apart.
            drop(fs::File::open(&path).map_err(|err| io(&err))?);
            IdentityKey::load(&path).map_err(|_| IdentityError::Corrupt)
        }

        Err(err) if err.kind() == ErrorKind::NotFound => {
            fs::create_dir_all(dir).map_err(|err| io(&err))?;
            let key = IdentityKey::generate();
            save_new(&key, &path)?;
            Ok(key)
        }

        Err(err) => Err(io(&err)),
    }
}

/// Reads and checks the server's bundle: upstream's `prekey-bundle.json` (`X3DHPublicBundle`, base64
/// fields). A signed identity X25519 key must verify under the bundle's identity key. The texts name no
/// path and no key.
pub fn load_bundle(path: &Path) -> Result<X3DHPublicBundle, String> {
    let size = fs::metadata(path)
        .map_err(|err| format!("the bundle file could not be read ({:?})", err.kind()))?
        .len();
    if size > MAX_BUNDLE_SIZE {
        return Err("the bundle file is too large to be a prekey bundle".into());
    }

    let text = fs::read(path)
        .map_err(|err| format!("the bundle file could not be read ({:?})", err.kind()))?;
    parse_bundle(&text)
}

/// [`load_bundle`] on bytes already read.
pub fn parse_bundle(json: &[u8]) -> Result<X3DHPublicBundle, String> {
    let bundle: X3DHPublicBundle = serde_json::from_slice(json)
        .map_err(|_| "the bundle file is not a valid rVPN prekey bundle".to_string())?;

    if let Some(signature) = &bundle.identity_x25519_signature {
        verify_identity_x25519_signature(
            &bundle.identity_key,
            &bundle.identity_x25519_key,
            signature,
        )
        .map_err(|_| "the bundle's identity signature is not valid".to_string())?;
    }

    Ok(bundle)
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use rvpn_core::crypto::X3DHResponder;

    /// A fresh, empty directory under the system temp directory, removed when dropped.
    pub(crate) struct TempDir(pub PathBuf);

    impl TempDir {
        pub(crate) fn new(name: &str) -> TempDir {
            let unique = format!(
                "wardkeep-rvpn-{name}-{}-{:?}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            );
            let path = std::env::temp_dir().join(unique);
            fs::create_dir_all(&path).unwrap();
            TempDir(path)
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn creates_then_loads_the_same_key() {
        let dir = TempDir::new("identity");
        let data = dir.0.join("nested").join("data");

        let created = load_or_create(&data).unwrap();
        let path = data.join(IDENTITY_FILE);
        assert!(path.is_file());
        assert!(!path.with_extension("key.tmp").exists());

        // Upstream's format: header line, public key, signing key.
        let text = fs::read_to_string(&path).unwrap();
        let lines: Vec<&str> = text.lines().collect();
        assert_eq!(lines.len(), 3);
        assert_eq!(lines[0], "R-VPN-IDENTITY-v1");

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = fs::metadata(&path).unwrap().permissions().mode();
            assert_eq!(mode & 0o777, 0o600);
        }

        let loaded = load_or_create(&data).unwrap();
        assert_eq!(
            loaded.verifying_key.to_bytes(),
            created.verifying_key.to_bytes()
        );
        assert_eq!(loaded.x25519_public_key(), created.x25519_public_key());

        // And upstream's own loader reads what was written.
        let upstream = IdentityKey::load(&path).unwrap();
        assert_eq!(
            upstream.verifying_key.to_bytes(),
            created.verifying_key.to_bytes()
        );
    }

    #[test]
    fn a_broken_key_file_is_kept() {
        let dir = TempDir::new("broken");
        let path = dir.0.join(IDENTITY_FILE);
        fs::write(&path, "not a key\n").unwrap();

        let err = load_or_create(&dir.0).err().unwrap();
        assert!(matches!(err, IdentityError::Corrupt));
        assert_eq!(fs::read_to_string(&path).unwrap(), "not a key\n");
        assert!(!err.to_string().contains(&*dir.0.to_string_lossy()));
    }

    #[test]
    fn a_stale_temporary_file_is_replaced() {
        let dir = TempDir::new("stale");
        fs::write(dir.0.join("identity.key.tmp"), "half").unwrap();

        load_or_create(&dir.0).unwrap();
        assert!(dir.0.join(IDENTITY_FILE).is_file());
        assert!(!dir.0.join("identity.key.tmp").exists());
    }

    #[test]
    fn parses_upstream_bundles() {
        let bundle = X3DHResponder::new().get_public_bundle();
        let json = serde_json::to_vec(&bundle).unwrap();
        let parsed = parse_bundle(&json).unwrap();
        assert_eq!(parsed.identity_key, bundle.identity_key);
        assert_eq!(parsed.identity_x25519_key, bundle.identity_x25519_key);

        // A legacy bundle without the signature is accepted (upstream's unsigned migration path).
        let mut legacy = bundle.clone();
        legacy.identity_x25519_signature = None;
        parse_bundle(&serde_json::to_vec(&legacy).unwrap()).unwrap();

        // A signature over another key is not.
        let mut forged = bundle;
        forged.identity_x25519_key[0] ^= 1;
        assert!(parse_bundle(&serde_json::to_vec(&forged).unwrap()).is_err());

        assert!(parse_bundle(b"{}").is_err());
        assert!(parse_bundle(b"not json").is_err());
    }

    #[test]
    fn bundle_file_errors_name_no_path() {
        let dir = TempDir::new("bundle");
        let missing = dir.0.join("prekey-bundle.json");
        let err = load_bundle(&missing).unwrap_err();
        assert!(!err.contains("prekey-bundle"), "{err}");

        fs::write(&missing, "x".repeat(70 * 1024)).unwrap();
        assert!(load_bundle(&missing).is_err());
    }
}
