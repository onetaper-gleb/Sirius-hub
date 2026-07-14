from __future__ import annotations

import html
import json
import re
from dataclasses import dataclass
from datetime import datetime
from http.cookiejar import CookieJar
from typing import Any
from urllib.request import HTTPCookieProcessor, Request, build_opener

ROOT_URL = "https://schedule.siriusuniversity.ru/"
LIVEWIRE_ENDPOINT = "https://schedule.siriusuniversity.ru/livewire/message/main-grid"


@dataclass
class LivewireState:
    token: str
    fingerprint: dict[str, Any]
    server_memo: dict[str, Any]


class SiriusScheduleClient:
    def __init__(self) -> None:
        cookie_jar = CookieJar()
        self._opener = build_opener(HTTPCookieProcessor(cookie_jar))

    def fetch_schedule(self, group: str, week_offset: int) -> list[dict[str, Any]]:
        state = self._get_initial_state()
        updates = self._build_updates(state.fingerprint["id"], group, week_offset)
        payload = {
            "_token": state.token,
            "fingerprint": state.fingerprint,
            "serverMemo": state.server_memo,
            "updates": updates,
        }
        response = self._post_livewire(payload)
        data = response.get("serverMemo", {}).get("data", {})
        return self._normalize_response(group, week_offset, data)

    def _get_initial_state(self) -> LivewireState:
        with self._opener.open(ROOT_URL, timeout=30) as response:
            page_html = response.read().decode("utf-8")

        state_match = re.search(r'wire:initial-data="([^"]+)"', page_html)
        if state_match is None:
            raise RuntimeError("Cannot find Livewire initial state")

        token_match = re.search(r"window\.livewire_token = '([^']+)';", page_html)
        if token_match is None:
            raise RuntimeError("Cannot find Livewire token")

        state = json.loads(html.unescape(state_match.group(1)))
        return LivewireState(
            token=token_match.group(1),
            fingerprint=state["fingerprint"],
            server_memo=state["serverMemo"],
        )

    def _build_updates(
        self, component_id: str, group: str, week_offset: int
    ) -> list[dict[str, Any]]:
        updates: list[dict[str, Any]] = [
            {
                "type": "callMethod",
                "payload": {
                    "id": component_id,
                    "method": "set",
                    "params": [group],
                },
            }
        ]

        if week_offset > 0:
            method = "addWeek"
            iterations = week_offset
        elif week_offset < 0:
            method = "minusWeek"
            iterations = abs(week_offset)
        else:
            return updates

        for _ in range(iterations):
            updates.append(
                {
                    "type": "callMethod",
                    "payload": {
                        "id": component_id,
                        "method": method,
                        "params": [],
                    },
                }
            )

        return updates

    def _post_livewire(self, payload: dict[str, Any]) -> dict[str, Any]:
        req = Request(
            LIVEWIRE_ENDPOINT,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json, text/plain, */*",
                "X-Livewire": "true",
                "X-Requested-With": "XMLHttpRequest",
                "Referer": ROOT_URL,
            },
            method="POST",
        )

        with self._opener.open(req, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))

    def _normalize_response(
        self, requested_group: str, week_offset: int, data: dict[str, Any]
    ) -> list[dict[str, Any]]:
        raw_events = data.get("events") or {}
        grouped: dict[str, dict[str, Any]] = {}

        if isinstance(raw_events, dict):
            event_lists = raw_events.values()
        elif isinstance(raw_events, list):
            event_lists = [raw_events]
        else:
            event_lists = []

        for event_list in event_lists:
            if not isinstance(event_list, list):
                continue

            for event in event_list:
                if not isinstance(event, dict):
                    continue

                date = event.get("date")
                day_week = event.get("dayWeek")
                if not date:
                    continue

                day_bucket = grouped.setdefault(
                    date,
                    {
                        "date": date,
                        "day_week": day_week,
                        "events": [],
                    },
                )

                teachers = event.get("teachers") or {}
                if isinstance(teachers, dict):
                    teacher_list = list(teachers.values())
                else:
                    teacher_list = []

                day_bucket["events"].append(
                    {
                        "start_time": event.get("startTime"),
                        "end_time": event.get("endTime"),
                        "number_pair": event.get("numberPair"),
                        "discipline": event.get("discipline"),
                        "group_type": event.get("groupType"),
                        "address": event.get("address"),
                        "classroom": event.get("classroom"),
                        "comment": event.get("comment"),
                        "place": event.get("place"),
                        "url_online": event.get("urlOnline"),
                        "group": event.get("group"),
                        "code": event.get("code"),
                        "color": event.get("color"),
                        "teachers": teacher_list,
                    }
                )

        days = sorted(
            grouped.values(), key=lambda item: self._parse_date(item.get("date"))
        )
        for day in days:
            day["events"].sort(
                key=lambda item: (
                    self._parse_time(item.get("start_time")),
                    item.get("number_pair") or 0,
                )
            )

        return days

    @staticmethod
    def _parse_date(value: Any) -> datetime:
        if not isinstance(value, str):
            return datetime.min
        try:
            return datetime.strptime(value, "%d.%m.%Y")
        except ValueError:
            return datetime.min

    @staticmethod
    def _parse_time(value: Any) -> datetime:
        if not isinstance(value, str):
            return datetime.min
        try:
            return datetime.strptime(value, "%H:%M")
        except ValueError:
            return datetime.min


if __name__ == "__main__":
    client = SiriusScheduleClient()
    print(client.fetch_schedule("ИОП-ИТ-24/1", 0))
    print(client.fetch_schedule("ИОП-ИТ-24/1", 5))
    print(client.fetch_schedule("ИОП-ИТ-24/1", -5))
