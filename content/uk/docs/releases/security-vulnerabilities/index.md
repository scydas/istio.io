---
title: Вразливості безпеки
description: Як ми обробляємо вразливості безпеки.
weight: 35
aliases:
    - /uk/about/security-vulnerabilities
    - /uk/latest/about/security-vulnerabilities
owner: istio/wg-docs-maintainers
test: n/a
---

Ми дуже вдячні дослідникам безпеки та користувачам, які повідомляють про вразливості безпеки в Istio. Ми ретельно досліджуємо кожен звіт.

## Повідомлення про вразливість {#reporting-a-vulnerability}

Щоб надіслати звіт, надішліть електронного листа на приватну адресу
[istio-security-vulnerability-reports@googlegroups.com](mailto:istio-security-vulnerability-reports@googlegroups.com) з деталями вразливості. Для звичайних помилок продукту, не повʼязаних із латентними вразливостями безпеки, будь ласка, відвідайте нашу сторінку [Повідомлення про помилки](/docs/releases/bugs/), щоб дізнатися, що робити.

### Коли повідомляти про вразливість безпеки? {#when-to-report-a-security-vulnerability}

Надсилайте нам звіт, коли ви:

- Вважаєте, що Istio має потенційну вразливість безпеки.
- Не впевнені, чи вплине вразливість на Istio і як саме.
- Вважаєте, що вразливість присутня в іншому проєкті, від якого залежить Istio. Наприклад, Envoy, Docker або Kubernetes.

У разі сумнівів, будь ласка, розкривайте інформацію приватно. Це включає, але не обмежується:

- Будь-який збій, особливо в Envoy
- Будь-яке обходження або слабкість політики безпеки (такої як автентифікація або авторизація)
- Будь-яке потенційне відмовлення в обслуговуванні (DoS)

### Коли не слід повідомляти про вразливість безпеки? {#when-not-to-report-a-security-vulnerability}

Не надсилайте звіт про вразливість, якщо:

- Вам потрібна допомога в налаштуванні компонентів Istio для безпеки.
- Вам потрібна допомога в застосуванні оновлень, що стосуються безпеки.
- Ваша проблема не повʼязана з безпекою.
- Ваша проблема повʼязана з залежностями базового образу (див. [Базові образи](#base-images))

## Оцінка {#evaluation}

Команда безпеки Istio розглядає та аналізує кожен звіт про вразливість протягом трьох робочих днів.

Будь-яка інформація про вразливість, яку ви надаєте команді безпеки Istio, залишається в межах проєкту Istio. Ми не поширюємо інформацію на інші проєкти. Ми ділимося інформацією лише в разі необхідності для виправлення проблеми.

Ми тримаємо вас (як особу, що повідомила про вразливість) в курсі того, як змінюється статус проблеми безпеки від `triaged` до `identified fix`, до `release planning`.

## Виправлення проблеми {#fixing-the-issue}

Коли вразливість безпеки повністю охарактеризована, команда Istio розробляє виправлення. Розробка та тестування виправлення відбуваються в приватному репозиторії GitHub, щоб уникнути передчасного розголосу вразливості.

## Раннє розкриття {#early-disclosure}

Проєкт Istio веде список розсилки для приватного раннього розкриття вразливостей безпеки. Список використовується для надання корисної інформації близьким партнерам Istio. Список не призначений для осіб, які хочуть дізнатися про проблеми безпеки.

Див. [Раннє розкриття вразливостей безпеки](https://github.com/istio/community/blob/master/EARLY-DISCLOSURE.md) для отримання додаткової інформації.

## Публічне розкриття {#public-disclosure}

У день, обраний для публічного розкриття, проводиться ряд заходів якомога швидше:

- Зміни з приватного репозиторію GitHub, що містить виправлення, зливаються у відповідні публічні гілки.

- Інженери з релізів забезпечують своєчасне створення та публікацію всіх необхідних бінарних файлів.

- Після того як бінарні файли стають доступними, надсилається оголошення через такі канали:

    - [Блог Istio](/blog)
    - Категорія [Оголошення](https://discuss.istio.io/c/announcements) на discuss.istio.io
    - [Twitter-аккаунт Istio](https://twitter.com/IstioMesh)
    - Канал [#announcements на Slack](https://istio.slack.com/messages/CFXS256EQ/)

Наскільки це можливо, це оголошення буде корисним і міститиме будь-які заходи помʼякшення, які клієнти можуть вжити перед оновленням до виправленої версії. Рекомендований цільовий час для таких оголошень — 16:00 UTC з понеділка по четвер. Це означає, що оголошення буде видно вранці на Тихоокеанському узбережжі, на початку вечора в Європі та пізно ввечері в Азії.

## Базові образи {#base-images}

Istio пропонує два набори docker-образів, основаних на `ubuntu` (стандартно) та на `distroless` (див. [Захист контейнерних образів](/docs/ops/configuration/security/harden-docker-images/)). Ці базові образи іноді мають CVE. Команда безпеки Istio автоматизувала сканування, щоб забезпечити відсутність CVE в базових образах.

Коли в наших образах виявляються CVE, нові образи автоматично створюються і використовуються для всіх майбутніх збірок. Крім того, команда безпеки аналізує вразливості, щоб перевірити, чи вони можуть бути експлуатовані безпосередньо в Istio. У більшості випадків ці вразливості можуть бути присутні в пакетах базового образу, але не є експлуатованими таким чином, як використовує їх Istio. У таких випадках нові релізи зазвичай не випускаються лише для виправлення цих CVE, а виправлення включаються в наступний плановий реліз.

Як результат, CVE базових образів не слід [повідомляти](#reporting-a-vulnerability), якщо немає доказів того, що їх можна експлуатувати в Istio.

Базові образи [`distroless`](/docs/ops/configuration/security/harden-docker-images/) наполегливо рекомендуються до використання, якщо вам важливо зменшити CVE базового образу.