# vicii-kawari-lib

Reusable 6502 assembly libraries for Commodore 64 programs that use VIC-II
Kawari extensions.

| Library | Purpose |
| --- | --- |
| [mailbox](mailbox/README.md) | Lets the C64's 6510 hand work to Kawari's 6502 co-processor through command lists in video RAM |
| [util](util/README.md) | Start-up routines: unlock Kawari's extended registers and check for a minimum firmware version |

See [AGENTS.md](AGENTS.md) for how to import a library into a project.
