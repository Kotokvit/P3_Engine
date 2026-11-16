---
name: poler-engine
description: >-
  Используй POLER-Engine и POLER Terminal Gateway для всех операций поиска,
  RAG-чанкинга с обратными координатами, анализа графов, безопасного исполнения команд
  и квантово-семантического поиска по кодовой базе и веб-индексу.
---

# 🔒 Навык POLER-Engine & Terminal Gateway [Ψ]

Этот навык обучает агента использовать исключительно детерминированное ядро `poler-engine`
для высокоточного поиска, графового анализа, RAG-чанкинга и защищенного выполнения команд.

## Основные команды:
1. **Точный полнотекстовый поиск (Native Grep):**
   ```bash
   poler-engine --grep "<ТЕКСТ>" --grep-after 3 [ПУТЬ]
   ```
2. **Структурный RAG-чанкинг:**
   ```bash
   poler-engine --chunk "<ФАЙЛ>" --chunk-size 300 --chunk-overlap 50 --chunk-json
   ```
3. **Квантово-семантический поиск (BM25 + WebRank + WHY):**
   ```bash
   poler-engine --query "<ЗАПРОС>" [ПУТЬ]
   ```
4. **Запуск терминального шлюза безопасности (Terminal Gateway):**
   ```bash
   poler-engine --gateway
   ```
5. **Проверка статуса лицензии:**
   ```bash
   poler-engine --license
   ```
