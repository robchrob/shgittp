Areas for Improvement (for v0.5.0)
Version Pinning
    Downloads from master/main branches (moving targets)
    Should use tagged releases or commit hashes

Checksum Verification
    No integrity checks on downloaded git binaries
    Should verify SHA256 checksums

Error Messages
    Some errors don't propagate clearly to local shell
    rerr() doesn't exit, relies on caller

Architecture Detection
    Only supports x86_64 and aarch64
    Missing: armv7, armv6, i686, etc.
