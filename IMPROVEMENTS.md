Requirements:
Minimalistic but complete (current parameters are enough), we need to work on determining if these below are done as we would expect.
Minimal dependencies on client (bash, network (curl or wget working), basic linux requirements (what scripts assumes is there or uses directly or indirecly)
Must be ultra to the point, all heavylifting must be done in shgittp, but we also need to keep code readable and short.

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
