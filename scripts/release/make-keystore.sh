#!/usr/bin/env bash
# Создаёт релизный ключ подписи Android и печатает значения для секретов GitHub.
#
#   bash scripts/release/make-keystore.sh            # только создать ключ и показать значения
#   bash scripts/release/make-keystore.sh --gh       # ещё и записать секреты в репозиторий через gh CLI
#
# Нужны: keytool (входит в JDK), openssl, base64. Для --gh: gh (https://cli.github.com), `gh auth login`.
set -euo pipefail

OUT_DIR="${OUT_DIR:-$HOME/journal-signing}"
KEYSTORE="$OUT_DIR/journal-release.jks"
ALIAS="journal"

command -v keytool >/dev/null || { echo "Не найден keytool — установите JDK 17+"; exit 1; }
command -v openssl >/dev/null || { echo "Не найден openssl"; exit 1; }

if [ -e "$KEYSTORE" ]; then
  echo "Ключ уже существует: $KEYSTORE"
  echo "Удалять его нельзя: без него невозможно обновить уже установленное приложение."
  exit 1
fi

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"
PASS="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)"

keytool -genkeypair -v \
  -keystore "$KEYSTORE" -storetype PKCS12 \
  -alias "$ALIAS" -keyalg RSA -keysize 4096 -validity 36500 \
  -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=Journal, OU=Journal, O=Journal, C=BY" >/dev/null 2>&1
chmod 600 "$KEYSTORE"

B64="$(base64 < "$KEYSTORE" | tr -d '\n')"

echo
echo "Готово. Ключ сохранён: $KEYSTORE"
echo "СОХРАНИТЕ этот файл и пароль в менеджере паролей (и сделайте копию)."
echo "Потеряете ключ — не сможете выпускать обновления поверх установленной версии."
echo
echo "Секреты GitHub (Settings → Secrets and variables → Actions → New repository secret):"
echo "  ANDROID_KEYSTORE_PASSWORD = $PASS"
echo "  ANDROID_KEY_PASSWORD      = $PASS"
echo "  ANDROID_KEY_ALIAS         = $ALIAS"
echo "  ANDROID_KEYSTORE_BASE64   = (содержимое файла $OUT_DIR/keystore.base64)"
printf '%s' "$B64" > "$OUT_DIR/keystore.base64"
chmod 600 "$OUT_DIR/keystore.base64"

if [ "${1:-}" = "--gh" ]; then
  command -v gh >/dev/null || { echo "gh не найден"; exit 1; }
  gh secret set ANDROID_KEYSTORE_BASE64   < "$OUT_DIR/keystore.base64"
  gh secret set ANDROID_KEYSTORE_PASSWORD --body "$PASS"
  gh secret set ANDROID_KEY_PASSWORD      --body "$PASS"
  gh secret set ANDROID_KEY_ALIAS         --body "$ALIAS"
  echo "Секреты записаны в репозиторий."
fi
