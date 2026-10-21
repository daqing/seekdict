# Dictionary data

SeekDict's English ⇄ Simplified Chinese glossary is vendored from the
[qingjian](https://github.com/qingjian-team/qingjian) project (`assets/glossary/`),
snapshot taken 2026-10-22 at upstream commit
[`7a2ccc7`](https://github.com/qingjian-team/qingjian/tree/7a2ccc769183403de4c8ccfd8fbd72fc96ed9579).

## Files

| File | Direction | Lines | SHA-256 |
|---|---|---|---|
| `glossary-zh.tsv` | English → Simplified Chinese (~45k words, keys lowercased) | 44,925 | `f56b59d7…48aff5e` |
| `glossary-en.tsv` | Chinese → English (~232k words) | 232,214 | `7b967697…b81625` |

## Format

TSV, one word per line: `word \t [pos.] sense \t [pos.] sense`

- UTF-8 without BOM, LF newlines, sorted by code point.
- At most 2 senses per word; the `[pos.] ` prefix is optional.
- POS enum: `n. v. adj. adv. pron. prep. conj. num. m. part. int. phr.`
- The first line of each file is a `#` comment and is skipped on import.

## License

The glossary tables © qingjian-team, published under **GPL-3.0-or-later**,
same as the upstream repository. SeekDict ships under the same license; see
[docs/README.md](../docs/README.md) and (once added) the root `LICENSE` file (T8.1).
