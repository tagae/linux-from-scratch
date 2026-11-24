# The account's GnuPG home is in memory, in /run/gnupg (run-gnupg.mount), where gpg-genkey keeps the
# keys it makes: no key reaches the SD card.
export GNUPGHOME=/run/gnupg
