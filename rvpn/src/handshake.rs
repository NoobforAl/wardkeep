// Copyright (C) 2024-2025 PDG Global Limited (Hong Kong)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Ported to Wardkeep from rvpn-core v1.3.9, rvpn/crates/rvpn-client/src/socks5_tunnel.rs
// (`Socks5Tunnel::perform_handshake`), with the ServerHello checks of
// rvpn/crates/rvpn-mobile/src/server_hello.rs (`ServerSecurity::validate`). Changed: the bundle is the pin
// (no known_hosts / trust on first use), the identity key is compared in constant time, and a signed
// identity X25519 key in the bundle is verified before use.

//! The X3DH handshake that opens a tunnel: Hello, ServerHello, and the Double Ratchet it yields.

use std::sync::Arc;
use std::time::Duration;

use rvpn_core::crypto::x3dh::X3DHInitiator;
use rvpn_core::crypto::{
    DoubleRatchet, IdentityKey, Signature, Verifier, VerifyingKey, X3DHPublicBundle,
    constant_time_eq, verify_identity_x25519_signature,
};
use rvpn_core::protocol::{AuthMethod, HandshakeMessage, ProtocolVersion};

use crate::error::ConnectError;
use crate::ws::{Message, Reader, Writer};

/// How long the server has to answer the Hello.
const SERVER_HELLO_TIMEOUT: Duration = Duration::from_secs(10);

const IDENTITY_MISMATCH: &str = "The server's identity key does not match the bundle.";
const BAD_SIGNATURE: &str = "The server's key signature is not valid.";
const REJECTED: &str = "The server rejected the handshake.";
const MALFORMED: &str = "The server's handshake answer is not valid.";

/// A key field of the ServerHello at its fixed size.
fn fixed<const N: usize>(bytes: &[u8], what: &str) -> Result<[u8; N], ConnectError> {
    bytes
        .try_into()
        .map_err(|_| ConnectError::handshake(MALFORMED, format!("{what} has the wrong length")))
}

/// Checks a ServerHello against the bundle and returns the bundle to run X3DH with.
///
/// - The ServerHello's identity key must be the bundle's (constant-time compare): the bundle is the pin.
/// - The signed prekey comes from the ServerHello (the server rotates it weekly) and must carry a valid
///   Ed25519 signature by that identity key.
/// - The identity X25519 key: when the ServerHello carries one with its signature, that signature must
///   verify and the key is used; with neither, the bundle's key is used, after its own signature (when
///   it has one) verifies; one without the other is rejected.
pub fn check_server_hello(
    message: HandshakeMessage,
    bundle: &X3DHPublicBundle,
) -> Result<X3DHPublicBundle, ConnectError> {
    let (identity_key, signed_prekey, prekey_signature, hello_x25519, hello_x25519_signature) =
        match message {
            HandshakeMessage::ServerHello {
                identity_key,
                signed_prekey,
                prekey_signature,
                identity_x25519_key,
                identity_x25519_signature,
                ..
            } => (
                identity_key,
                signed_prekey,
                prekey_signature,
                identity_x25519_key,
                identity_x25519_signature,
            ),

            // The server's own words are not logged: only its code.
            HandshakeMessage::Error { code, .. } => {
                return Err(ConnectError::handshake(
                    REJECTED,
                    format!("server error code {code}"),
                ));
            }

            _ => {
                return Err(ConnectError::handshake(MALFORMED, "not a ServerHello"));
            }
        };

    let identity: [u8; 32] = fixed(&identity_key, "the identity key")?;
    let signed_prekey: [u8; 32] = fixed(&signed_prekey, "the signed prekey")?;
    let prekey_signature: [u8; 64] = fixed(&prekey_signature, "the prekey signature")?;

    if !constant_time_eq(&identity, &bundle.identity_key) {
        return Err(ConnectError::handshake(
            IDENTITY_MISMATCH,
            "identity key differs from the bundle",
        ));
    }

    let verifying = VerifyingKey::from_bytes(&identity)
        .map_err(|_| ConnectError::handshake(MALFORMED, "the identity key is not a valid key"))?;
    verifying
        .verify(&signed_prekey, &Signature::from_bytes(&prekey_signature))
        .map_err(|_| ConnectError::handshake(BAD_SIGNATURE, "prekey signature"))?;

    let identity_x25519 = match (hello_x25519, hello_x25519_signature) {
        (Some(key), Some(signature)) => {
            let key: [u8; 32] = fixed(&key, "the identity X25519 key")?;
            let signature: [u8; 64] = fixed(&signature, "the identity X25519 signature")?;
            verify_identity_x25519_signature(&identity, &key, &signature).map_err(|_| {
                ConnectError::handshake(BAD_SIGNATURE, "identity X25519 signature (ServerHello)")
            })?;
            key
        }

        (None, None) => {
            if let Some(signature) = &bundle.identity_x25519_signature {
                verify_identity_x25519_signature(
                    &bundle.identity_key,
                    &bundle.identity_x25519_key,
                    signature,
                )
                .map_err(|_| {
                    ConnectError::handshake(BAD_SIGNATURE, "identity X25519 signature (bundle)")
                })?;
            }

            bundle.identity_x25519_key
        }

        // A key with no signature (or the reverse): a server that signs sends both.
        _ => {
            return Err(ConnectError::handshake(
                MALFORMED,
                "only part of the signed identity X25519 key",
            ));
        }
    };

    Ok(X3DHPublicBundle {
        identity_key: identity,
        identity_x25519_key: identity_x25519,
        identity_x25519_signature: bundle.identity_x25519_signature,
        signed_prekey,
        prekey_signature,
        one_time_prekey: None,
        identity_key_version: bundle.identity_key_version,
        rotation_signature: bundle.rotation_signature,
    })
}

/// The client's Hello for `initiator`.
fn hello(initiator: &X3DHInitiator) -> HandshakeMessage {
    HandshakeMessage::Hello {
        version: ProtocolVersion::CURRENT,
        auth_method: AuthMethod::X3DH,
        ephemeral_key: Some(initiator.ephemeral_key.public_key.to_bytes().to_vec()),
        identity_key: Some(initiator.identity_key.x25519_public_key().to_vec()),
        session_token: None,
        connection_nonce: None,
    }
}

/// Sends the Hello, checks the ServerHello ([`check_server_hello`]) and runs X3DH: the Double Ratchet of
/// the tunnel, this side as Alice.
pub async fn perform(
    reader: &mut Reader,
    writer: &Writer,
    identity: &Arc<IdentityKey>,
    bundle: &X3DHPublicBundle,
) -> Result<DoubleRatchet, ConnectError> {
    let initiator = X3DHInitiator::from_identity_key(Arc::clone(identity));
    let hello = serde_json::to_vec(&hello(&initiator))
        .map_err(|_| ConnectError::handshake(MALFORMED, "the Hello could not be encoded"))?;
    writer
        .send(Message::Binary(hello.into()))
        .await
        .map_err(|_| ConnectError::network("closed before the Hello was sent"))?;

    let answer = tokio::time::timeout(SERVER_HELLO_TIMEOUT, async {
        loop {
            match reader.recv().await {
                Some(Message::Binary(data)) => return Ok(data),
                // WebSocket pings and pongs may come first.
                Some(Message::Ping(_) | Message::Pong(_)) => {}
                Some(Message::Close(_)) | None => {
                    return Err(ConnectError::network("closed during the handshake"));
                }

                Some(_) => {
                    return Err(ConnectError::handshake(MALFORMED, "not a binary message"));
                }
            }
        }
    })
    .await
    .map_err(|_| ConnectError::network("no ServerHello in time"))??;

    let server_hello: HandshakeMessage = serde_json::from_slice(&answer)
        .map_err(|_| ConnectError::handshake(MALFORMED, "the ServerHello is not valid JSON"))?;
    let agreed = check_server_hello(server_hello, bundle)?;

    let (shared, _material) = initiator
        .agree(&agreed)
        .map_err(|_| ConnectError::handshake(MALFORMED, "X3DH key agreement failed"))?;
    Ok(DoubleRatchet::init_alice(shared, [0u8; 32]))
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use crate::error::Code;
    use rvpn_core::crypto::X3DHResponder;

    /// The ServerHello upstream's server sends (rvpn-server handler.rs `server_hello`).
    pub(crate) fn server_hello(bundle: &X3DHPublicBundle, signed: bool) -> HandshakeMessage {
        HandshakeMessage::ServerHello {
            ephemeral_key: Vec::new(),
            signed_prekey: bundle.signed_prekey.to_vec(),
            prekey_signature: bundle.prekey_signature.to_vec(),
            identity_key: bundle.identity_key.to_vec(),
            identity_x25519_key: signed.then(|| bundle.identity_x25519_key.to_vec()),
            identity_x25519_signature: if signed {
                bundle.identity_x25519_signature.map(|sig| sig.to_vec())
            } else {
                None
            },
        }
    }

    fn code_of(result: Result<X3DHPublicBundle, ConnectError>) -> (Code, &'static str) {
        let err = result.unwrap_err();
        (err.code, err.message)
    }

    #[test]
    fn accepts_the_pinned_server() {
        let responder = X3DHResponder::new();
        let bundle = responder.get_public_bundle();

        for signed in [true, false] {
            let agreed = check_server_hello(server_hello(&bundle, signed), &bundle).unwrap();
            assert_eq!(agreed.identity_key, bundle.identity_key);
            assert_eq!(agreed.identity_x25519_key, bundle.identity_x25519_key);
            assert_eq!(agreed.signed_prekey, bundle.signed_prekey);
        }
    }

    /// The prekey rotates: a ServerHello with a newer signed prekey than the bundle's is accepted.
    #[test]
    fn takes_the_rotated_prekey_from_the_server_hello() {
        let identity = IdentityKey::generate();
        let old = X3DHResponder::from_identity(identity.clone()).get_public_bundle();
        let new = X3DHResponder::from_identity(identity).get_public_bundle();
        assert_ne!(old.signed_prekey, new.signed_prekey);

        let agreed = check_server_hello(server_hello(&new, true), &old).unwrap();
        assert_eq!(agreed.signed_prekey, new.signed_prekey);
    }

    #[test]
    fn rejects_another_identity() {
        let bundle = X3DHResponder::new().get_public_bundle();
        let other = X3DHResponder::new().get_public_bundle();

        assert_eq!(
            code_of(check_server_hello(server_hello(&other, true), &bundle)),
            (Code::Handshake, IDENTITY_MISMATCH)
        );
    }

    #[test]
    fn rejects_a_bad_prekey_signature() {
        let bundle = X3DHResponder::new().get_public_bundle();
        let mut forged = bundle.clone();
        forged.signed_prekey[3] ^= 0x40;

        assert_eq!(
            code_of(check_server_hello(server_hello(&forged, true), &bundle)),
            (Code::Handshake, BAD_SIGNATURE)
        );
    }

    #[test]
    fn rejects_a_bad_x25519_signature() {
        let bundle = X3DHResponder::new().get_public_bundle();

        // In the ServerHello: the key swapped for another one, the signature kept.
        let mut forged = bundle.clone();
        forged.identity_x25519_key = X3DHResponder::new().get_public_bundle().identity_x25519_key;
        assert_eq!(
            code_of(check_server_hello(server_hello(&forged, true), &bundle)),
            (Code::Handshake, BAD_SIGNATURE)
        );

        // In the bundle, with a ServerHello that carries none.
        let mut bad_bundle = bundle.clone();
        bad_bundle.identity_x25519_signature = Some([7u8; 64]);
        assert_eq!(
            code_of(check_server_hello(
                server_hello(&bundle, false),
                &bad_bundle
            )),
            (Code::Handshake, BAD_SIGNATURE)
        );
    }

    #[test]
    fn rejects_half_a_signed_key_and_errors() {
        let bundle = X3DHResponder::new().get_public_bundle();
        let HandshakeMessage::ServerHello {
            ephemeral_key,
            signed_prekey,
            prekey_signature,
            identity_key,
            identity_x25519_key,
            ..
        } = server_hello(&bundle, true)
        else {
            unreachable!()
        };

        let half = HandshakeMessage::ServerHello {
            ephemeral_key,
            signed_prekey,
            prekey_signature,
            identity_key,
            identity_x25519_key,
            identity_x25519_signature: None,
        };
        assert_eq!(
            code_of(check_server_hello(half, &bundle)),
            (Code::Handshake, MALFORMED)
        );

        let refused = HandshakeMessage::Error {
            code: 3,
            message: "X3DH not available".into(),
        };
        assert_eq!(
            code_of(check_server_hello(refused, &bundle)),
            (Code::Handshake, REJECTED)
        );
    }

    #[test]
    fn rejects_wrong_lengths() {
        let bundle = X3DHResponder::new().get_public_bundle();
        let short = HandshakeMessage::ServerHello {
            ephemeral_key: Vec::new(),
            signed_prekey: vec![0; 31],
            prekey_signature: bundle.prekey_signature.to_vec(),
            identity_key: bundle.identity_key.to_vec(),
            identity_x25519_key: None,
            identity_x25519_signature: None,
        };
        assert_eq!(
            code_of(check_server_hello(short, &bundle)),
            (Code::Handshake, MALFORMED)
        );
    }
}
