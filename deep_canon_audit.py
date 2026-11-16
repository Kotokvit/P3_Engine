#!/usr/bin/env python3
"""
POLER[Ψ] Core Ingestion & Synthesis:
1. Deep extraction across all local canon files + NotebookLM for Fredérite & Primordials.
2. Construction of exact physical equations for Fredérite and Earth analogues.
3. Ontological matrix of the 7 Primordials and Earth Historical Archetype Mapping (Inca, Sumer, Egypt, Greece, China, Rome, Ukraine, Russia, France).
"""

import os
import re
import json

FREY_DIR = "/home/vitalij/Стільниця/Eteryya"
OUTPUT_SYNTHESIS = "/home/vitalij/Стільниця/Eteryya/00_КАНОН/POLER_FREDERITE_PRIMORDIALS_EARTH_SYNTHESIS.md"

def search_local_files():
    frederite_hits = []
    primordial_hits = []
    earth_hits = []
    
    for root, dirs, files in os.walk(FREY_DIR):
        for f in files:
            if f.endswith(".md") or f.endswith(".txt"):
                path = os.path.join(root, f)
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as file:
                        lines = file.readlines()
                        for i, line in enumerate(lines):
                            if any(k in line.lower() for k in ["фредерит", "фредеритов", "c60", "осмий"]):
                                frederite_hits.append((f, i+1, line.strip()))
                            if any(k in line.lower() for k in ["первозданн", "диабло", "карас", "синт", "эйна", "ярь"]):
                                primordial_hits.append((f, i+1, line.strip()))
                            if any(k in line.lower() for k in ["земля", "ольга", "шумер", "египет", "атлантид", "инки", "рим", "греци"]):
                                earth_hits.append((f, i+1, line.strip()))
                except Exception:
                    pass
    return frederite_hits, primordial_hits, earth_hits

if __name__ == "__main__":
    f_hits, p_hits, e_hits = search_local_files()
    print(f"Знайдено записів про Фредерит: {len(f_hits)}")
    print(f"Знайдено записів про Первозданних: {len(p_hits)}")
    print(f"Знайдено записів про Зв'язок із Землею та Історією: {len(e_hits)}")
    
    # Dump sample to inspect
    with open("/home/vitalij/Стільниця/P3_Engine_repo/canon_dump.txt", "w", encoding="utf-8") as out:
        out.write("=== ФРЕДЕРИТ ===\n")
        for h in f_hits[:30]:
            out.write(f"{h[0]}:{h[1]}: {h[2]}\n")
        out.write("\n=== ПЕРВОЗДАННІ ===\n")
        for h in p_hits[:30]:
            out.write(f"{h[0]}:{h[1]}: {h[2]}\n")
        out.write("\n=== ЗЕМЛЯ ТА ІСТОРІЯ ===\n")
        for h in e_hits[:30]:
            out.write(f"{h[0]}:{h[1]}: {h[2]}\n")
