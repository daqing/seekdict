# 词典数据

SeekDict 的英 ⇄ 简中释义表引入自
[qingjian](https://github.com/qingjian-team/qingjian) 项目(`assets/glossary/`),
快照截取于 2026-10-22,上游 commit
[`7a2ccc7`](https://github.com/qingjian-team/qingjian/tree/7a2ccc769183403de4c8ccfd8fbd72fc96ed9579)。

## 文件

| 文件 | 方向 | 行数 | SHA-256 |
|---|---|---|---|
| `glossary-zh.tsv` | 英语 → 简体中文(约 4.5 万词,键为小写) | 44,925 | `f56b59d7…48aff5e` |
| `glossary-en.tsv` | 中文 → 英语(约 23.2 万词) | 232,214 | `7b967697…b81625` |

## 格式

TSV,一行一词:`词 \t [词性.] 译词 \t [词性.] 译词`

- UTF-8 无 BOM,LF 换行,按码点排序。
- 每词最多 2 个义项;`[词性.] ` 前缀可省略。
- 词性枚举:`n. v. adj. adv. pron. prep. conj. num. m. part. int. phr.`
- 每个文件首行为 `#` 注释,导入时跳过。

## 许可证

释义词表 © qingjian-team,以 **GPL-3.0-or-later** 发布,与上游仓库一致。
SeekDict 采用相同许可证发布;见 [docs/README.md](../docs/README.md)
及(后续补充的)根目录 `LICENSE` 文件(T8.1)。
