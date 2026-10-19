"""Prints a manifest of a package archive, to compare two builds of a package with diff.

Usage: python3 -I archive-manifest.py ARCHIVE.tar.xz > manifest

One line per entry, sorted by path: F path mode sha256-prefix, L path -> target (symlink),
H path -> target (hard link), D path mode. Modification times, owners and sizes are left out: they say
nothing about the contents. Two builds of a package that match line for line installed the same files.
"""
import hashlib
import sys
import tarfile

with tarfile.open(sys.argv[1]) as archive:
    for member in sorted(archive.getmembers(), key=lambda m: m.name):
        mode = oct(member.mode & 0o7777)[2:]
        if member.issym():
            print(f"L {member.name} -> {member.linkname}")
        elif member.islnk():
            print(f"H {member.name} -> {member.linkname}")
        elif member.isdir():
            print(f"D {member.name} {mode}")
        elif member.isfile():
            digest = hashlib.sha256(archive.extractfile(member).read()).hexdigest()[:16]
            print(f"F {member.name} {mode} {digest}")
        else:
            print(f"? {member.name} {member.type!r}")
