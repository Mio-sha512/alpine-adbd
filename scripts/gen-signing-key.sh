#!/bin/sh
# gen-signing-key.sh -- one-time generation of the persistent abuild signing
# keypair used to sign the published apk repository. Run locally; the private
# key goes into the 'release' GitHub environment secret, the public key ships
# inside the published repo for clients to install into /etc/apk/keys/.
#
#   ./scripts/gen-signing-key.sh
#   gh secret set ABUILD_PRIVATE_KEY --env release < keys/alpine-adbd.rsa
#
# (everything under keys/ is gitignored except *.rsa.pub -- never commit the
#  private half.)
set -eu
umask 077

REPO="$(cd "$(dirname "$0")/.." && pwd)"
KEYS="$REPO/keys"
NAME="alpine-adbd"

mkdir -p "$KEYS"
if [ -f "$KEYS/$NAME.rsa" ]; then
	echo "key already exists: $KEYS/$NAME.rsa" >&2
	exit 1
fi

openssl genrsa -out "$KEYS/$NAME.rsa" 4096
openssl rsa -in "$KEYS/$NAME.rsa" -pubout -out "$KEYS/$NAME.rsa.pub"
chmod 600 "$KEYS/$NAME.rsa"
chmod 644 "$KEYS/$NAME.rsa.pub"

cat <<EOF
Generated:
  private: $KEYS/$NAME.rsa
  public:  $KEYS/$NAME.rsa.pub

Next steps:
  1. gh secret set ABUILD_PRIVATE_KEY --env release < $KEYS/$NAME.rsa
     (environment-scoped, not a repo-level secret -- see README)
  2. Keep the private key backed up somewhere safe (password manager etc.);
     rotating it later means re-deploying the new public key to every
     device -- apk has no revocation, a leaked key stays trusted until
     removed from /etc/apk/keys/ on each device.
  3. Optionally: git add $KEYS/$NAME.rsa.pub -- the committed public key is
     a second, independent trust channel for fresh installs.
  4. Remove the on-disk private key once the secret is stored:
     shred -u $KEYS/$NAME.rsa
EOF
