import asyncio
import json
import os
import sys
from pathlib import Path

from telethon import TelegramClient
from telethon.tl.types import ChannelParticipantAdmin, ChannelParticipantCreator


def participant_status(user):
    participant = getattr(user, "participant", None)
    if isinstance(participant, ChannelParticipantCreator):
        return "creator"
    if isinstance(participant, ChannelParticipantAdmin):
        return "administrator"
    return "member"


def serialize_user(user):
    return {
        "id": user.id,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "username": user.username,
        "is_bot": bool(user.bot),
        "status": participant_status(user),
    }


async def synchronize(chat_id):
    api_id = int(os.environ["TELEGRAM_API_ID"])
    api_hash = os.environ["TELEGRAM_API_HASH"]
    bot_token = os.environ["POLICR_MINI_BOT_TOKEN"]
    session_path = Path(
        os.environ.get(
            "TELEGRAM_MEMBER_SYNC_SESSION",
            "/home/policr_mini/member_sync_data/wufeng_bot",
        )
    )
    session_path.parent.mkdir(parents=True, exist_ok=True)
    session_path.parent.chmod(0o700)

    client = TelegramClient(str(session_path), api_id, api_hash)
    try:
        await client.start(bot_token=bot_token)
        session_file = Path(f"{session_path}.session")
        if session_file.exists():
            session_file.chmod(0o600)
        entity = await client.get_entity(chat_id)
        participants = await client.get_participants(entity)
        members = [serialize_user(user) for user in participants]
        return {
            "success": True,
            "chat_id": chat_id,
            "telegram_count": int(getattr(participants, "total", len(members))),
            "fetched_count": len(members),
            "members": members,
        }
    finally:
        await client.disconnect()


def main():
    if len(sys.argv) != 2:
        raise ValueError("chat_id is required")
    result = asyncio.run(synchronize(int(sys.argv[1])))
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(
            json.dumps(
                {"success": False, "error": f"{type(error).__name__}: {error}"},
                ensure_ascii=False,
                separators=(",", ":"),
            )
        )
        raise SystemExit(1)
