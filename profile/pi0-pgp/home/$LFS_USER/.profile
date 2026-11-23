# The account's GnuPG home is in memory, in /run/gnupg (run-gnupg.mount), where gpg-genkey keeps the
# keys it makes: no key reaches the SD card.
export GNUPGHOME=/run/gnupg

# systemd refuses to power the machine off for any account but root (there is no polkit). Its
# poweroff, reboot and halt exit without a word when it does, and systemctl says why.
alias poweroff='systemctl poweroff'
alias reboot='systemctl reboot'
alias halt='systemctl halt'
