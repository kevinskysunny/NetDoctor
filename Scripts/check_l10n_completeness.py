#!/usr/bin/env python3
"""L10n 完整性检查脚本。

统计 Localization.swift 中 8 种语言各 key 数量，断言均 248。
若 T2 已完成拆分，则扫描 L10n_*.swift 分文件；否则扫描 Localization.swift 单文件。

退出码：
  0 — 全部通过
  1 — 有语言缺口
"""

import re
import sys
from pathlib import Path

EXPECTED_KEY_COUNT = 262
LANGUAGES = ["zh", "en", "ja", "ko", "de", "fr", "es", "pt"]

L10N_DIR = Path("Sources/NetworkConsoleApp")


def extract_keys_from_file(filepath: Path, dict_name: str) -> set:
    """从指定文件中提取指定字典的 key 集合。"""
    content = filepath.read_text(encoding="utf-8")
    pattern = rf"static let {dict_name}:\s*\[String:\s*String\]\s*=\s*\[(.*?)\n\s*\]"
    m = re.search(pattern, content, re.DOTALL)
    if not m:
        return set()
    block = m.group(1)
    return set(re.findall(r'"([^"]+)"\s*:', block))


def get_l10n_file(lang: str) -> Path:
    """获取指定语言的字典所在文件（拆分后 L10n_<lang>.swift 或未拆分 Localization.swift）。"""
    split_file = L10N_DIR / f"L10n_{lang}.swift"
    if split_file.exists():
        return split_file
    return L10N_DIR / "Localization.swift"


def main() -> int:
    all_pass = True
    print("=" * 60)
    print("L10n 完整性检查")
    print("=" * 60)

    for lang in LANGUAGES:
        filepath = get_l10n_file(lang)
        keys = extract_keys_from_file(filepath, lang)
        count = len(keys)
        status = "✅" if count == EXPECTED_KEY_COUNT else "❌"
        print(f"  {lang}: {count} key {status}")
        if count != EXPECTED_KEY_COUNT:
            all_pass = False
            en_keys = extract_keys_from_file(get_l10n_file("en"), "en")
            missing = en_keys - keys
            extra = keys - en_keys
            if missing:
                print(f"    缺失 {len(missing)} key: {sorted(missing)[:10]}...")
            if extra:
                print(f"    多余 {len(extra)} key: {sorted(extra)[:10]}...")

    print("=" * 60)
    if all_pass:
        print(f"✅ 全部 {len(LANGUAGES)} 语言均 {EXPECTED_KEY_COUNT} key，缺口清零")
        return 0
    else:
        print("❌ 存在语言缺口，请补齐")
        return 1


if __name__ == "__main__":
    sys.exit(main())