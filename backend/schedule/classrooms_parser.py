import asyncio
import json
from datetime import datetime, timedelta

import aiohttp
import requests
from bs4 import BeautifulSoup


class ScheduleParsingError(Exception):
    """Exception that rises in errors in response answer."""

    pass


class NetworkError(Exception):
    """Network exception"""

    pass


class ParsingError(Exception):
    """Parsing from login request has ended with Error"""

    pass


class Schedule:

    def __init__(self):

        self.__URL_LOGIN_CLASSROOM = "https://schedule.siriusuniversity.ru/classroom"
        self.__URL_CLASSROOM = "https://schedule.siriusuniversity.ru/livewire/message/classroom.classroom-main-grid"

        self.__lessons = [
            0,
            60 * 10 + 5,
            60 * 11 + 40,
            60 * 13 + 15,
            60 * 14 + 50,
            60 * 16 + 25,
            60 * 18,
            60 * 19 + 35,
        ]

        self.__classrooms = []
        self.__all_classrooms = {}
        self.__updated_classrooms = None

    """
    This function gets the list of all classrooms from the university website
    and updates the internal classrooms list.
    """

    async def classroom_list(self, meaning, next=False):
        if type(meaning) != str or type(next) != type(False):
            raise TypeError(
                "Meaning must be a string. Type of variable next must be Bull."
            )

        session = aiohttp.ClientSession()
        session.headers.update(
            {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 YaBrowser/26.4.0.0 Safari/537.36"
            }
        )

        # Prepairing web-page for main request session.
        try:
            async with session.get(
                "https://schedule.siriusuniversity.ru/classroom"
            ) as resp:
                text = await resp.text()
        except Exception as e:
            await session.close()
            raise NetworkError(f"error: {e}")

        soup = BeautifulSoup(text, "html.parser")
        all_divs = soup.find_all("div")

        # We look for meta info that is hidden in the body of last request
        for link in all_divs:
            if link.get("wire:id"):
                wire = json.loads(link.get("wire:initial-data"))
                break
        else:
            await session.close()
            raise ParsingError("No serverMemo found. Maybe problem with URL. ")

        all_scripts = soup.find_all("script")

        for link in all_scripts:
            if link.text.count("livewire_token"):
                token = link.text[121:161]
                break
        else:
            await session.close()
            raise ParsingError("No token found. Maybe problem with URL.")

        # Setting data
        payload = {
            "updates": [
                {
                    "type": "syncInput",
                    "payload": {"id": "xe6x", "name": "search", "value": meaning},
                }
            ],
            "fingerprint": wire["fingerprint"],
            "serverMemo": wire["serverMemo"],
        }

        # Setting headers
        headers = {
            "Content-type": "application/json",
            "X-CSRF-TOKEN": token,
            "X-livewire": "true",
            "Origin": "https://schedule.siriusuniversity.ru",
            "Referer": "https://schedule.siriusuniversity.ru/classroom",
        }

        # Requesting schedule from web-site
        try:
            async with session.post(
                "https://schedule.siriusuniversity.ru/livewire/message/classroom.classroom-main-grid",
                headers=headers,
                json=payload,
            ) as response:
                ans = await response.json()
            if "serverMemo" in ans:
                payload["serverMemo"] = ans["serverMemo"]
            if "fingerprint" in ans:
                payload["fingerprint"] = ans["fingerprint"]

            classroomlist = payload["serverMemo"]["data"]["classroomsList"]
            for value in classroomlist.values():
                if (
                    ("Сириус" in value)
                    or ("К_У" in value)
                    or ('Корпус "Спорт"' in value)
                ):
                    continue
                elif "Альфа" in value:
                    first_index = value.find("Альфа")
                    if value.count("Альфа") > 1:
                        second_index = value.find("Альфа", first_index + len("Альфа"))
                        new_value = value[second_index:]
                    else:
                        new_value = value[first_index:]
                elif 'К_' in value and (value.startswith('1') or value.startswith('2')):
                    first_index = value.find('К_')
                    if value.count('.') < 2:
                        new_value = value[first_index:]
                    elif value.count(".") == 2:
                        new_value = value[(first_index - 5) :]
                    else:
                        new_value = value[(first_index - 6) :]
                elif "Бета" in value:
                    first_index = value.find("Бета")
                    if value.count("Бета") > 1:
                        second_index = value.find("Бета", first_index + len("Бета"))
                        new_value = value[second_index:]
                    else:
                        new_value = value[first_index:]
                elif "Дельта" in value:
                    index = value.find("Дельта")
                    new_value = value[index:]
                self.__all_classrooms[value] = new_value
        # Resetting position on web-site

        except Exception as e:
            await session.close()
            raise NetworkError("Failed to make request to sirius university.")
        except:
            await session.close()

            raise NetworkError("Failed to make request to sirius university.")

        await session.close()

    async def get_classrooms(self):
        self.__all_classrooms = {}
        await asyncio.gather(
            self.classroom_list("альфа"),
            self.classroom_list("К"),
            self.classroom_list("бета"),
            self.classroom_list("дельта"),
        )
        self.__classrooms = list(self.__all_classrooms.keys())
        self.__updated_classrooms = datetime.now()

    """
    This function checks whether the classrooms list to be updated.
    The list is updated if it is empty or hasn't been updated for more than 1 week.
    """

    async def update_classroom_list(self):
        need_update = (
            (not self.__classrooms)
            or (self.__updated_classrooms is None)
            or (datetime.now() - self.__updated_classrooms > timedelta(days=7))
        )
        if need_update:
            await self.get_classrooms()

    """
    This function gives you this week schedule for certain classroom.
    String with valid group name. (Group names must be written with '-' instead of ' ')
    Also you can choose between this week or next week.
    '''
    async def classroom(self, number, next=False):
        # Choosing method to use.
        # If we need second week of different from previous classroom, then we need to change page to new classroom.
        if type(number) != str or type(next) != type(False):
            raise TypeError('Group number must be a string. Type of variable next must be Bull.')

        method = 'set'
        if next:
            method = 'addWeek'

        session = aiohttp.ClientSession()
        session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 YaBrowser/25.8.0.0 Safari/537.36'
        })

        # Prepairing web-page for main request session.
        try:
            async with session.get(self.__URL_LOGIN_CLASSROOM) as resp:
                text = await resp.text()
        except Exception as e:
            await session.close()
            raise NetworkError('error')

        soup = BeautifulSoup(text, 'html.parser')
        all_divs = soup.find_all('div')

        # We look for meta info that is hidden in the body of last request
        for link in all_divs:
          if link.get('wire:id'):
            wire = json.loads(link.get('wire:initial-data'))
            break
        else:
            await session.close()
            raise ParsingError('No serverMemo found. Maybe problem with URL. ')

        all_scripts = soup.find_all('script')

        for link in all_scripts:
            if link.text.count('livewire_token'):
                token = link.text[121:161]
                break
        else:
            await session.close()
            raise ParsingError('No token found. Maybe problem with URL.')

        # Setting data
        payload = {
          "updates": [
            {
              "type": "callMethod",
              "payload": {
                "id": "get1",
                "method": method,
                "params": [number]
              }
            }
          ],
          "fingerprint": wire['fingerprint'],
          "serverMemo": wire['serverMemo'],
        }

        # Setting headers
        headers = {
            'Content-type': 'application/json',
            'X-CSRF-TOKEN': token,
            'X-livewire': 'true',
            'Origin': 'https://schedule.siriusuniversity.ru',
            'Referer': 'https://schedule.siriusuniversity.ru/'
        }

        # Requesting schedule from web-site
        try:
            async with session.post(self.__URL_CLASSROOM, headers=headers, json=payload) as response:
                ans = await response.json()
            # Resetting position on web-site
            payload['updates'][0]['payload']['method'] = 'minusWeek'
            async with session.post(self.__URL_CLASSROOM, headers=headers, json=payload) as r:
                pass
        except:
            await session.close()

            raise NetworkError("Failed to make request to sirius university.")

        
        # Creates the returning dictionary
        schedule = {
            0: [],
            1: [],
            2: [],
            3: [],
            4: [],
            5: [],
            6: [],
            'classroom': number
        }

        # Parsing response structure
        try:
            if not ans['serverMemo']['data'].get('events', 0):
                await session.close()
                return number
            for i in ans['serverMemo']['data']['events'].keys():
                for j in ans['serverMemo']['data']['events'][i]:
                    if type(j['teachers']) == dict:
                        j['teacher'] = j['teachers'][list(j['teachers'].keys())[0]]
                        if type(j['teacher']) != str:
                            del j['teacher']['id']
                        del j['teachers']
                    del j['code']
                    del j['color']
                    if not i.startswith('Д'):
                        j['numberPair'] = int(i[:1]) + 1
                        schedule[int(i[2:3])].append(j)
                    else:
                        hour, minute = map(lambda x: int(x), j['startTime'].split(":"))
                        for m, time in enumerate(self.__lessons):
                            if time > hour * 60 + minute:
                                pair = m
                                break
                        j['numberPair'] = pair
                        schedule[int(i[4:5])].append(j)
            for i in list(schedule.keys())[:-1]:
                schedule[i].sort(key=lambda x: x['numberPair'])
        except Exception as e:
            await session.close()
            raise ScheduleParsingError("Error in parsing server response. Might be wrong group name.")

        await session.close()
        return schedule

    """
    This function gives you free classrooms for certain time of today.
    """

    async def get_free_classrooms(self, date=datetime.now()):
        # TODO delete classroom time dependent updates, move them to main and stick them to timer
        await self.update_classroom_list()
        # Collecting schedules
        all_classrooms = await asyncio.gather(
            *(self.classroom(classroom) for classroom in self.__classrooms[:20])
        )
        all_classrooms_2 = await asyncio.gather(
            *(self.classroom(classroom) for classroom in self.__classrooms[20:40])
        )
        all_classrooms_3 = await asyncio.gather(
            *(self.classroom(classroom) for classroom in self.__classrooms[40:])
        )

        all_classrooms = all_classrooms + all_classrooms_2 + all_classrooms_3
        keys_for_free_classrooms = []
        pair = 0

        # Defining which pair is it now.
        for i, time in enumerate(self.__lessons):
            if time > date.hour * 60 + date.minute:
                pair = i
                break

        # Finding free classrooms
        for i in all_classrooms:
            if type(i) == str:
                keys_for_free_classrooms.append(i)
                continue
            for j in i[date.weekday()]:
                if j["numberPair"] == pair:
                    break
                elif j["numberPair"] > pair:
                    keys_for_free_classrooms.append(i["classroom"])
                    break
            else:
                keys_for_free_classrooms.append(i["classroom"])

        free_classrooms = [
            self.__all_classrooms[key] for key in keys_for_free_classrooms
        ]
        return sorted(free_classrooms)


async def main():
    sc = Schedule()

    free_classrooms = await sc.get_free_classrooms(date=datetime(2026, 7, 10, 9))
    print(free_classrooms)
    print(f"Свободных аудиторий: {len(free_classrooms)}")


if __name__ == "__main__":
    asyncio.run(main())