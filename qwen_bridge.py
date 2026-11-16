#!/usr/bin/env python3
"""
Qwen Deep Research Bridge over CDP.
Target: https://chat.qwen.ai/c/94dc34a2-28ce-4cd1-b610-76eae08329be
"""

import sys
import asyncio
from playwright.async_api import async_playwright

QWEN_URL = "https://chat.qwen.ai/c/94dc34a2-28ce-4cd1-b610-76eae08329be"

async def query_qwen(prompt_text):
    print(f"🌐 Підключення до сесії Qwen Deep Research...")
    async with async_playwright() as p:
        browser = await p.chromium.connect_over_cdp("http://localhost:9222")
        context = browser.contexts[0]
        page = None
        for p_item in context.pages:
            if "chat.qwen.ai" in p_item.url:
                page = p_item
                break
        if not page:
            page = await context.new_page()
            await page.goto(QWEN_URL)
            await page.wait_for_timeout(5000)
            
        await page.bring_to_front()
        print(f"📄 Qwen сторінка активна: {page.url}")
        
        # We find chat box
        input_box = await page.wait_for_selector("textarea, [contenteditable='true']", timeout=10000)
        if input_box:
            full_prompt = f"[GitHub Context: https://github.com/Kotokvit/Eteryya]\n\n{prompt_text}"
            await input_box.click()
            await input_box.fill(full_prompt)
            await page.keyboard.press("Enter")
            print("🚀 Запит відправлено в Qwen! Глибоке дослідження запущено.")
        else:
            print("❌ Не знайдено поля вводу в Qwen.")

if __name__ == "__main__":
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Проведи глубокий аудит и исследование репозитория https://github.com/Kotokvit/Eteryya по архео-физике сопряжения Земли и Этерии."
    asyncio.run(query_qwen(prompt))
