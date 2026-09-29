from __future__ import annotations

import logging
import os
import re
from pathlib import Path
from uuid import uuid4

from dotenv import load_dotenv
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    CommandHandler,
    ConversationHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

from catalog import FUNCTIONS, GROUPS, FUNCTION_BY_ID
from package3105 import write_package
from store import FunctionStore

load_dotenv()
logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger("3105-telegram-bot")

WAIT_DOCUMENT, WAIT_BUNDLE, WAIT_PATH, WAIT_PASSWORD, WAIT_PASSWORD_VALUE = range(5)
ROOT = Path(os.getenv("BOT_DATA_DIR", "./bot_data")).resolve()
STORE = FunctionStore(ROOT)
ADMIN_IDS = {int(item.strip()) for item in os.getenv("TELEGRAM_ADMIN_IDS", "").split(",") if item.strip().isdigit()}


def is_admin(update: Update) -> bool:
    user = update.effective_user
    return bool(user and user.id in ADMIN_IDS)


def groups_keyboard() -> InlineKeyboardMarkup:
    rows = [[InlineKeyboardButton(name, callback_data=f"group:{group_id}")] for group_id, name in GROUPS.items()]
    return InlineKeyboardMarkup(rows)


def functions_keyboard(group_id: str) -> InlineKeyboardMarkup:
    rows = []
    for item in FUNCTIONS:
        if item.group_id == group_id:
            entry = STORE.get(item.id)
            status = "ATIVA" if entry["status"] == "active" else "MANUTENÇÃO"
            published = "• publicada" if entry.get("package") else "• sem arquivo"
            rows.append([InlineKeyboardButton(f"{item.name} [{status}] {published}", callback_data=f"fn:{item.id}")])
    rows.append([InlineKeyboardButton("⬅ Voltar", callback_data="back:groups")])
    return InlineKeyboardMarkup(rows)


def function_keyboard(function_id: str) -> InlineKeyboardMarkup:
    entry = STORE.get(function_id)
    status_action = "maintenance" if entry["status"] == "active" else "active"
    status_label = "Colocar em manutenção" if entry["status"] == "active" else "Ativar função"
    rows = [
        [InlineKeyboardButton("Publicar/substituir .3105", callback_data=f"publish:{function_id}")],
        [InlineKeyboardButton(status_label, callback_data=f"status:{status_action}:{function_id}")],
    ]
    if entry.get("package"):
        rows.append([InlineKeyboardButton("Excluir arquivo publicado", callback_data=f"delete:{function_id}")])
    rows.append([InlineKeyboardButton("⬅ Voltar", callback_data=f"back:group:{entry['group_id']}")])
    return InlineKeyboardMarkup(rows)


def function_text(function_id: str) -> str:
    item = FUNCTION_BY_ID[function_id]
    entry = STORE.get(function_id)
    return (
        f"*{item.group_name}*\n*{item.name}*\n\n"
        f"Identificador: `{function_id}`\n"
        f"Status: *{entry['status']}*\n"
        f"Versão publicada: `{entry.get('version', 0)}`\n"
        f"Arquivo: `{entry.get('package') or 'nenhum'}`"
    )


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_admin(update):
        await update.effective_message.reply_text("Acesso restrito ao administrador configurado.")
        return
    await update.effective_message.reply_text("Painel 3105 — selecione um grupo:", reply_markup=groups_keyboard())


async def callback(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int | None:
    query = update.callback_query
    await query.answer()
    if not is_admin(update):
        await query.edit_message_text("Acesso restrito ao administrador configurado.")
        return ConversationHandler.END
    data = query.data or ""
    if data == "back:groups":
        await query.edit_message_text("Selecione um grupo:", reply_markup=groups_keyboard())
        return ConversationHandler.END
    if data.startswith("group:"):
        group_id = data.split(":", 1)[1]
        await query.edit_message_text(GROUPS[group_id], reply_markup=functions_keyboard(group_id))
        return ConversationHandler.END
    if data.startswith("fn:"):
        function_id = data.split(":", 1)[1]
        await query.edit_message_text(function_text(function_id), parse_mode="Markdown", reply_markup=function_keyboard(function_id))
        return ConversationHandler.END
    if data.startswith("back:group:"):
        group_id = data.rsplit(":", 1)[1]
        await query.edit_message_text(GROUPS[group_id], reply_markup=functions_keyboard(group_id))
        return ConversationHandler.END
    if data.startswith("status:"):
        _, status, function_id = data.split(":", 2)
        STORE.set_status(function_id, status)
        await query.edit_message_text(function_text(function_id), parse_mode="Markdown", reply_markup=function_keyboard(function_id))
        return ConversationHandler.END
    if data.startswith("delete:"):
        function_id = data.split(":", 1)[1]
        context.user_data["delete_function_id"] = function_id
        keyboard = InlineKeyboardMarkup([
            [InlineKeyboardButton("Confirmar exclusão", callback_data=f"delete_confirm:{function_id}")],
            [InlineKeyboardButton("Cancelar", callback_data=f"fn:{function_id}")],
        ])
        await query.edit_message_text("Excluir o arquivo publicado desta função? A função ficará em manutenção.", reply_markup=keyboard)
        return ConversationHandler.END
    if data.startswith("delete_confirm:"):
        function_id = data.split(":", 1)[1]
        STORE.delete_package(function_id)
        await query.edit_message_text("Arquivo removido e função colocada em manutenção.", reply_markup=function_keyboard(function_id))
        return ConversationHandler.END
    if data.startswith("publish:"):
        function_id = data.split(":", 1)[1]
        context.user_data.clear()
        context.user_data["function_id"] = function_id
        await query.edit_message_text(
            f"Envie agora o arquivo de substituição para *{FUNCTION_BY_ID[function_id].name}*.",
            parse_mode="Markdown",
        )
        return WAIT_DOCUMENT
    if data.startswith("password:"):
        choice, function_id = data.split(":", 2)[1:]
        context.user_data["function_id"] = function_id
        if choice == "no":
            return await finalize_publish(update, context, password=None)
        await query.edit_message_text("Digite a senha do pacote. Ela não será exibida no catálogo público:")
        return WAIT_PASSWORD_VALUE
    return ConversationHandler.END


async def receive_document(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not is_admin(update) or not update.message or not update.message.document:
        return ConversationHandler.END
    document = update.message.document
    function_id = context.user_data.get("function_id")
    if function_id not in FUNCTION_BY_ID:
        await update.message.reply_text("Sessão expirada. Use /start novamente.")
        return ConversationHandler.END
    upload_dir = ROOT / "uploads"
    upload_dir.mkdir(parents=True, exist_ok=True)
    safe_name = re.sub(r"[^A-Za-z0-9._-]", "_", document.file_name or "replacement.bin")
    destination = upload_dir / f"{uuid4().hex}_{safe_name}"
    telegram_file = await document.get_file()
    await telegram_file.download_to_drive(destination)
    context.user_data["upload_path"] = str(destination)
    await update.message.reply_text("Informe o Bundle ID, por exemplo: `com.dts.freefireth`", parse_mode="Markdown")
    return WAIT_BUNDLE


async def receive_bundle(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not is_admin(update) or not update.message:
        return ConversationHandler.END
    context.user_data["bundle_id"] = update.message.text.strip()
    await update.message.reply_text(
        "Informe o caminho relativo COMPLETO do arquivo dentro do app, incluindo o nome final.\n"
        "Exemplo: `hsneck/3D` (não informe apenas a pasta)."
    )
    return WAIT_PATH


async def receive_path(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not is_admin(update) or not update.message:
        return ConversationHandler.END
    context.user_data["relative_path"] = update.message.text.strip()
    function_id = context.user_data["function_id"]
    keyboard = InlineKeyboardMarkup([
        [InlineKeyboardButton("Sim, proteger com senha", callback_data=f"password:yes:{function_id}")],
        [InlineKeyboardButton("Não usar senha", callback_data=f"password:no:{function_id}")],
    ])
    await update.message.reply_text("Deseja proteger o pacote .3105 com senha?", reply_markup=keyboard)
    return WAIT_PASSWORD


async def receive_password(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not is_admin(update) or not update.message:
        return ConversationHandler.END
    return await finalize_publish(update, context, password=update.message.text)


async def finalize_publish(update: Update, context: ContextTypes.DEFAULT_TYPE, password: str | None) -> int:
    function_id = context.user_data.get("function_id")
    if function_id not in FUNCTION_BY_ID:
        await update.effective_message.reply_text("Sessão expirada. Use /start novamente.")
        return ConversationHandler.END
    try:
        upload_path = Path(context.user_data["upload_path"])
        bundle_id = context.user_data["bundle_id"]
        relative_path = context.user_data["relative_path"].strip()
        if not relative_path or relative_path.endswith(("/", "\\")):
            raise ValueError("Informe o caminho completo do arquivo, incluindo o nome final")
        item = FUNCTION_BY_ID[function_id]
        author = update.effective_user.full_name if update.effective_user else "3105 Admin"
        package_path = ROOT / "generated" / f"{function_id.replace('.', '_')}.3105"
        write_package(
            package_path,
            function_id=function_id,
            function_name=item.name,
            author=author,
            bundle_id=bundle_id,
            relative_path=relative_path,
            replacement_filename=Path(relative_path).name,
            replacement_data=upload_path.read_bytes(),
            password=password or None,
        )
        entry = STORE.publish(function_id, package_path.read_bytes(), bool(password))
        upload_path.unlink(missing_ok=True)
        package_path.unlink(missing_ok=True)
        await update.effective_message.reply_text(
            f"Publicado com sucesso.\n\nFunção: {item.name}\nID: `{function_id}`\n"
            f"Versão: `{entry['version']}`\nCaminho: `{relative_path}`\n"
            f"Senha: `{'sim' if password else 'não'}`",
            parse_mode="Markdown",
            reply_markup=function_keyboard(function_id),
        )
    except Exception as exc:
        LOGGER.exception("publish failed")
        await update.effective_message.reply_text(f"Não foi possível criar o pacote: {exc}")
    context.user_data.clear()
    return ConversationHandler.END


async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data.clear()
    await update.effective_message.reply_text("Operação cancelada.")
    return ConversationHandler.END


def build_application() -> Application:
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    if not token:
        raise RuntimeError("Defina TELEGRAM_BOT_TOKEN no ambiente")
    conversation = ConversationHandler(
        entry_points=[CallbackQueryHandler(callback, pattern=r"^publish:")],
        states={
            WAIT_DOCUMENT: [MessageHandler(filters.Document.ALL, receive_document)],
            WAIT_BUNDLE: [MessageHandler(filters.TEXT & ~filters.COMMAND, receive_bundle)],
            WAIT_PATH: [MessageHandler(filters.TEXT & ~filters.COMMAND, receive_path)],
            WAIT_PASSWORD: [CallbackQueryHandler(callback, pattern=r"^password:")],
            WAIT_PASSWORD_VALUE: [MessageHandler(filters.TEXT & ~filters.COMMAND, receive_password)],
        },
        fallbacks=[CommandHandler("cancel", cancel)],
        per_user=True,
        per_chat=True,
    )
    app = Application.builder().token(token).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(conversation)
    app.add_handler(CallbackQueryHandler(callback))
    return app
