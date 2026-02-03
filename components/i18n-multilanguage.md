# i18n для мультиязычных проектов

> Skill для разработки приложений с поддержкой множества языков

## Когда использовать

- SaaS с международной аудиторией
- Приложения с 2+ языками интерфейса
- Проекты с планами на локализацию

---

## 1. Архитектура файлов переводов

### Модульная структура (рекомендуется)

```text
lang/
├── en/
│   ├── common.json      # UI: кнопки, статусы, ошибки
│   ├── validation.json  # Валидация форм
│   ├── {domain}.json    # Бизнес-домены: billing, metrics
│   └── pages.json       # Страницы: dashboard, profile
├── ru/
│   └── ...
└── de/
    └── ...
```

### Один файл (для маленьких проектов)

```text
lang/
├── en.json
├── ru.json
└── de.json
```

### Правила

| Правило | Значение |
|---------|----------|
| Размер файла | < 500 ключей, иначе разбивать |
| Вложенность | Максимум 2-3 уровня |
| Кодировка | UTF-8 везде |

---

## 2. Именование ключей

### Формат

```text
{namespace}.{component}.{element}
```

### Примеры

```json
{
  "common.button.save": "Save",
  "common.button.cancel": "Cancel",
  "common.status.loading": "Loading...",
  "validation.email.invalid": "Invalid email format",
  "validation.required": "This field is required",
  "dashboard.stats.total_users": "Total Users",
  "billing.plan.upgrade": "Upgrade Plan",
  "flash.success.saved": "Changes saved"
}
```

### Запрещено

```json
// ❌ Бессмысленные ID
"btn1": "Save",
"text_234": "Welcome",

// ❌ Текст как ключ (сломается при переводе)
"Save changes": "Save changes",
"Welcome to our app": "Welcome to our app"
```

---

## 3. Модули по доменам

| Модуль | Префиксы | Содержимое |
|--------|----------|------------|
| `common` | `common.*`, `validation.*`, `error.*`, `auth.*` | Переиспользуемые строки |
| `{domain}` | `billing.*`, `metrics.*`, `report.*` | Бизнес-логика |
| `pages` | `dashboard.*`, `settings.*`, `profile.*` | Страницы |

---

## 4. Три золотых правила (Shopify)

### Правило 1: Интерполируй осторожно

```javascript
// ❌ Плохо — фрагментирует предложение
t('welcome') + ' ' + userName + '!'

// ✅ Хорошо — единая строка с плейсхолдером
t('welcome', { name: userName })
```

```json
{
  "welcome": "Welcome, {name}!"
}
```

### Правило 2: Не конструируй предложения в коде

```javascript
// ❌ Плохо — порядок слов зависит от языка
const msg = t('you_have') + count + t('new_messages')

// ✅ Хорошо — полное предложение
const msg = t('new_messages_count', { count })
```

### Правило 3: Используй библиотеки для сложной логики

Не пиши свою логику для:

- Множественных форм (plural)
- Гендерных согласований
- Склонений

---

## 5. Plural Forms (множественные числа)

### Проблема

```javascript
// Английский: 1 site, 2 sites — 2 формы
// Русский: 1 сайт, 2 сайта, 5 сайтов — 3 формы
// Арабский: 6 форм!
```

### Решение (vue-i18n / i18next)

```json
// en.json
{
  "sites.count": "No sites | {n} site | {n} sites"
}

// ru.json
{
  "sites.count": "Нет сайтов | {n} сайт | {n} сайта | {n} сайтов"
}
```

```javascript
t('sites.count', count)  // Автоматически выберет форму
```

---

## 6. Date / Number / Currency

### Проблема

```javascript
// ❌ Хардкод формата
`${day}.${month}.${year}`  // RU: 03.02.2026, US: 02/03/2026
```

### Решение — Intl API

```javascript
// Даты
new Intl.DateTimeFormat(locale).format(date)

// Числа
new Intl.NumberFormat(locale).format(1234.5)
// EN: "1,234.5"
// RU: "1 234,5"
// DE: "1.234,5"

// Валюта
new Intl.NumberFormat(locale, {
  style: 'currency',
  currency: 'USD'
}).format(99)
```

### Vue composable

```javascript
const { d, n } = useI18n()
d(new Date(), 'short')   // Дата по конфигу локали
n(1234.5, 'currency')    // Число как валюта
```

---

## 7. Гибкий UI для разных языков

### Проблема длины текста

| Язык | Относительная длина |
|------|---------------------|
| English | 100% (базовый) |
| German | 120-130% |
| Russian | 110-120% |
| Chinese | 80-90% |
| Arabic | 100-110% |

### Решение

```css
/* ❌ Плохо — фиксированные размеры */
.button { width: 120px; }

/* ✅ Хорошо — гибкие размеры */
.button {
  min-width: 80px;
  padding: 8px 16px;
  white-space: nowrap;
}

/* ✅ Или ограничение с переносом */
.label {
  max-width: 200px;
  overflow-wrap: break-word;
}
```

---

## 8. Псевдо-локализация (тестирование)

Тестируй UI **до** реального перевода:

```javascript
// Оригинал
"Save"

// Псевдо-локализация
"[Šåṿḗḗḗḗḗḗḗḗḗḗḗḗḗḗḗḗḗḗḗḗ]"  // Длинный текст + спецсимволы
```

### Что находит

- Обрезанный текст
- Проблемы с кодировкой
- Захардкоженные строки (не обёрнутые в `t()`)
- Сломанный layout

---

## 9. Популярные библиотеки

| Framework | Библиотека | Особенности |
|-----------|------------|-------------|
| **React** | react-i18next | Хуки, HOC, SSR |
| **React** | react-intl (FormatJS) | ICU MessageFormat |
| **Vue** | vue-i18n | Composition API, SFC |
| **Next.js** | next-intl | App Router, RSC |
| **Angular** | @angular/localize | Встроенный |
| **Universal** | i18next | Работает везде |

---

## 10. Загрузка переводов (Laravel + Vue)

### Backend (Inertia middleware)

```php
// HandleInertiaRequests.php
protected function getTranslations(): array
{
    $locale = app()->getLocale();
    $dir = lang_path($locale);

    // Модульный формат (приоритет)
    if (is_dir($dir)) {
        $translations = [];
        foreach (glob("{$dir}/*.json") as $file) {
            $translations = array_merge(
                $translations,
                json_decode(file_get_contents($file), true) ?? []
            );
        }
        if (!empty($translations)) return $translations;
    }

    // Fallback на один файл
    $file = lang_path("{$locale}.json");
    return file_exists($file)
        ? json_decode(file_get_contents($file), true) ?? []
        : [];
}
```

### Frontend (Vue 3)

```javascript
// i18n.js
import { createI18n } from 'vue-i18n'

export function createI18nInstance(translations, locale) {
    return createI18n({
        legacy: false,
        locale,
        messages: { [locale]: translations },
        missing: (_, key) => key,  // Показывать ключ если нет перевода
    })
}

// В компоненте:
const { t } = useI18n()
t('common.button.save')
```

---

## 11. AI-assisted перевод

### Быстрый перевод через Claude

```bash
# Перевод JSON файла
cat lang/en/common.json | claude "Translate values to Russian. Keep JSON keys unchanged. Output valid JSON only."

# С контекстом
cat lang/en/billing.json | claude "Translate to German. Context: SaaS billing interface. Keep technical terms (API, OAuth) as-is."
```

### Проверка недостающих ключей

```bash
# Сравнить ключи между локалями
diff <(jq -r 'keys[]' lang/en/common.json | sort) \
     <(jq -r 'keys[]' lang/ru/common.json | sort)
```

---

## 12. CI/CD инструменты

| Инструмент | Тип | Интеграция |
|------------|-----|------------|
| [Localazy](https://localazy.com) | CLI + TMS | GitHub, GitLab |
| [Crowdin](https://crowdin.com) | TMS | Git, API |
| [Lingo.dev](https://github.com/lingodotdev/lingo.dev) | AI-powered | GitHub Actions |
| [Locize](https://locize.com) | i18next + CDN | Realtime updates |

### GitHub Action пример

```yaml
- name: Sync translations
  run: |
    npx localazy upload
    npx localazy download
```

---

## 13. Добавление нового языка

```bash
# 1. Копировать базовый язык
cp -r lang/en lang/sv

# 2. Перевести (вручную или AI)
cat lang/sv/common.json | claude "Translate to Swedish..."

# 3. Добавить в конфиг
# config/app.php
'available_locales' => ['en', 'ru', 'sv']

# 4. Проверить покрытие
diff <(jq -r 'keys[]' lang/en/common.json | sort) \
     <(jq -r 'keys[]' lang/sv/common.json | sort)
```

---

## 14. Checklist перед релизом

- [ ] Все строки обёрнуты в `t()`
- [ ] Нет конкатенации строк
- [ ] Plural forms для счётчиков
- [ ] Даты/числа через Intl API
- [ ] UI тестирован на длинных текстах (DE)
- [ ] Fallback на базовый язык работает
- [ ] Ключи одинаковые во всех локалях

---

## Что пропустить (для большинства проектов)

| Фича | Когда нужна | Вердикт |
|------|-------------|---------|
| RTL (right-to-left) | Арабский, иврит | ⏭️ Пропустить если нет планов |
| Lazy loading переводов | 10k+ ключей | ⏭️ Преждевременная оптимизация |
| Гендерные согласования | Редко в UI | ⏭️ По необходимости |

---

## Источники

- [i18next Best Practices](https://www.i18next.com/principles/best-practices)
- [Shopify i18n for Front-End](https://shopify.engineering/internationalization-i18n-best-practices-front-end-developers)
- [Namespaces in Localization](https://simplelocalize.io/blog/posts/namespace/)
- [Continuous Localization](https://lokalise.com/blog/continuous-localization-101/)
