# Sources, attribution and scope

This is an unofficial Windows desktop pet maintained by hige6 with AI assistance, unrelated to and not endorsed by OpenAI. It is derived from GPT-Niang; upstream copyright and asset notices are preserved.

| Component | Pinned upstream commit | Reuse |
| --- | --- | --- |
| [T7moris/GPT-Niang](https://github.com/T7moris/GPT-Niang) | `b6f5eb8972d1802821006b7208d20a834fa6a08b` | Windows PowerShell 5.1/WPF application, XAML bubble, native Win32/DWM follower, alpha hit testing, scaling, settings, isolated Node quota worker and tests. MIT source/documentation, copyright 2026 T7moris and contributors. Original root LICENSE retained. |
| [fywdy/chatgpt-chibi-pets](https://github.com/fywdy/chatgpt-chibi-pets) | `d5bbb27c79e5c08e8b8ab44d4023cd35a67418e2` | White dragon chibi v5 WebP, pet.json, README, validation and review records. Atlas layout/timing from upstream tools/check-contract.py and tools/verify-previews.py. JSON/scripts MIT; art CC BY-NC 4.0. Author/source: fywdy, chatgpt-chibi-pets contributors. |
| [PC2005-cloud/dsh-pet](https://github.com/PC2005-cloud/dsh-pet) | `cf3ed3c4dd6829b252f352d4c61a18db6fdb26d4` | Research reference only: shared animation configuration, state-to-action mapping, separate browser/native renderer. No code, bundled animal art, dependencies or host copied. Source MIT; art/prompts/video have separate noncommercial restrictions. |

`gpt-niang-usage/assets/dragon-v5/UPSTREAM-LICENSE`, `UPSTREAM-LICENSE-MIT`, and `UPSTREAM-NOTICE.md` preserve the actual pack licenses and unofficial fan-art statement. CC BY-NC 4.0: https://creativecommons.org/licenses/by-nc/4.0/

Derived files: spritesheet.png is a pixel-identical RGBA decode of spritesheet.webp; idle.png is the unscaled first frame; preview PNGs are WPF renders. No character repainting or recoloring. These derived images retain the art license, attribution and noncommercial restriction. Original GPT-Niang image assets remain with their own `CHARACTER-NOTICE.txt`, outside MIT source scope. Do not interpret the source MIT license as permission to commercially redistribute any character artwork.

The official directory links to PC2005-cloud/dsh-pet. At the pinned source it uses transparent WebM/MOV actions and config.jsonc species definitions (`Animations`, `PetSpecies` in src/shared/types.ts), rather than this Codex v2 pet.json atlas. No pet.json or hatch-pet entry was found in that checkout. Its standalone runtime exists, but is a separate Electron/video path; the full DSH plugin is not used here.

Quota protocol reference: [OpenAI App Server documentation](https://learn.chatgpt.com/docs/app-server). The protocol uses initialize/initialized, account/read with refreshToken:false, then account/rateLimits/read. No conversation/model generation request is made.

The source is published for noncommercial desktop-pet use under the component licenses above. Publication does not grant additional third-party character or trademark rights. The MIT code license does not override the separate artwork restrictions.

Video preview update: four user-supplied Doubao MP4 clips were keyed and normalized into `assets/dragon-video/` RGBA frames. They derive from the same white dragon character; preserve fywdy/chatgpt-chibi-pets attribution and CC BY-NC 4.0 noncommercial restrictions. Source names and SHA-256 appear in pack.json. Original MP4s were not modified or bundled. These derived frames, WebP previews and showcase video do not acquire the code's MIT license. No dsh-pet processing code or Agnes-generated character test was copied into the desktop pack.
