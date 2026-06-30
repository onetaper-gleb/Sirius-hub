from schedule.parser import SiriusScheduleClient


def test_build_updates_for_positive_and_negative_offsets():
    client = SiriusScheduleClient()

    plus_updates = client._build_updates("component-id", "GROUP-1", 2)
    minus_updates = client._build_updates("component-id", "GROUP-1", -1)
    zero_updates = client._build_updates("component-id", "GROUP-1", 0)

    assert len(plus_updates) == 3
    assert plus_updates[0]["payload"]["method"] == "set"
    assert plus_updates[1]["payload"]["method"] == "addWeek"
    assert plus_updates[2]["payload"]["method"] == "addWeek"

    assert len(minus_updates) == 2
    assert minus_updates[1]["payload"]["method"] == "minusWeek"

    assert len(zero_updates) == 1
    assert zero_updates[0]["payload"]["method"] == "set"


def test_normalize_response_groups_days_and_sorts_events():
    client = SiriusScheduleClient()
    data = {
        "events": {
            "one": [
                {
                    "date": "03.01.2025",
                    "dayWeek": "Fri",
                    "startTime": "12:00",
                    "endTime": "13:30",
                    "numberPair": 2,
                    "discipline": "Math",
                    "teachers": {"t1": "Иванов И.И."},
                },
                {
                    "date": "02.01.2025",
                    "dayWeek": "Thu",
                    "startTime": "10:00",
                    "endTime": "11:30",
                    "numberPair": 1,
                    "discipline": "Physics",
                    "teachers": {"t2": "Петров П.П."},
                },
                {
                    "date": "03.01.2025",
                    "dayWeek": "Fri",
                    "startTime": "09:00",
                    "endTime": "10:30",
                    "numberPair": 1,
                    "discipline": "Biology",
                    "teachers": {"t3": "Сидоров С.С."},
                },
            ]
        }
    }

    days = client._normalize_response("GROUP-1", 0, data)

    assert len(days) == 2
    assert days[0]["date"] == "02.01.2025"
    assert days[1]["date"] == "03.01.2025"
    assert [event["discipline"] for event in days[1]["events"]] == ["Biology", "Math"]


def test_normalize_response_skips_items_without_date():
    client = SiriusScheduleClient()
    data = {
        "events": {
            "one": [
                {"date": "", "startTime": "10:00", "discipline": "Broken"},
                {"dayWeek": "Tue", "startTime": "09:00", "discipline": "Broken 2"},
            ]
        }
    }

    days = client._normalize_response("GROUP-1", 0, data)
    assert days == []


def test_parse_date_and_time_return_min_for_invalid_values():
    client = SiriusScheduleClient()

    assert client._parse_date("wrong-date").year == 1
    assert client._parse_date(None).year == 1
    assert client._parse_time("99:99").year == 1
    assert client._parse_time(None).year == 1
