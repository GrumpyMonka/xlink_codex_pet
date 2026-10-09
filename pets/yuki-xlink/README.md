# Yuki XLink

Separate revised Yuki package. Author: [XLink](https://github.com/GrumpyMonka/xlink_codex_pet).

Works only with XLink Player. The Codex player option is disabled for this package. Select the package in XLink Codex Pets and apply. The original Yuki remains a separate package.

New artwork was generated using the built-in imagegen tool, then cropped into complete frames. This package contains only one set of 57 animation PNGs. Frames are not a cutout body rig or optical-flow interpolation. The left run mirrors the right run. The generation brief: preserve silver hair/red eyes/black XLink hoodie; coherent adjacent poses; fixed cel shading; clean transparent background; full-body anatomically attached limbs. Separate sheets cover an eight-phase run, idle/greeting/hop, disappointment/waiting, dance/thinking.

| Event | Frames | XLink cycle |
|---|---:|---:|
| idle | 6 | 0.72 s |
| running-right / running-left | 8 each | 1.46 s |
| waving | 4 | 0.57 s |
| jumping | 5 | 0.89 s |
| failed | 8 | 1.08 s |
| waiting | 6 | 0.88 s |
| running | 6 | 1.08 s |
| review | 6 | 0.77 s |

XLink frames use a 384 × 416 transparent canvas. This is the output canvas size, not a claim of equivalent original detail in every generated frame. There is no native atlas or second low-resolution frame set. The pack does not claim 30 or 60 unique frames per second.

All actions use balanced 120–200ms frame holds. Similar poses change slightly faster; larger pose changes are held longer. The exact project SVG replaces generated emblems on all 57 frames.
