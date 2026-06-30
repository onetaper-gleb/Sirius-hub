import asyncio
import datetime

import aiohttp
import requests
from bs4 import BeautifulSoup
import json


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
        self.URL_LOGIN_GROUP = "https://schedule.siriusuniversity.ru/"
        self.URL_GROUP = 'https://schedule.siriusuniversity.ru/livewire/message/main-grid'

        self.URL_LOGIN_CLASSROOM = "https://schedule.siriusuniversity.ru/classroom"
        self.URL_CLASSROOM = 'https://schedule.siriusuniversity.ru/livewire/message/classroom.classroom-main-grid'

        self.lessons = [0, 60 * 10 + 5, 60 * 11 + 40, 60 * 13 + 15, 60 * 14 + 50,
                   60 * 16 + 25, 60 * 18, 60 * 19 + 35]

        self.classrooms = [
            "1.10. К_Гринатом (Основной)",
            "1.19 К_РЖД ОЦРВ (Основной)",
            "К_25 (Основной)",
            "1.20. К_Росатом (Робототехника) (Основной)",
            "1.18. К_Ростелеком (Основной)",
            "К_3 (Основной)",
            "К_5 (Основной)",
            "К_0 (стартап-лаборатория ИНТЦ) (Основной)",
            "К_2 (Основной)",
            "К_6 (Основной)",
            "К_9 (Основной)",
            "К_11 (Основной)",
            "К_7 (Основной)",
            "Альфа 5.8 (Основной)",
            "К_1 (Основной)",
            "К_4 (Основной)",
            "К_10 (Основной)",
            "К_8 (Основной)",
            "Альфа 5.2 (Основной)",
            "Альфа 5.3 (Основной)",
            "Альфа 4.3 (Основной)",
            "Альфа 4.1 (Основной)",
            "Альфа 4.2 (Основной)",
            "Альфа 4.4 (Основной)",
            "Альфа 5.1 (Основной)",
            "1.16 К_Газпром нефть (Основной)",
            "1.17. К_АстраЛинукс (Основной)",
            "Альфа 5.7 (Основной)",
            "Альфа 5.12.1 Финтех (комп) (Основной)",
            "Дельта 2.3 (Основной)",
            "Бета 4.1 (компьютерный класс) (Основной)",
            "Альфа 5.12.2 (Основной)",
            "Альфа 5.4 (Основной)",
            "Альфа 5.11 (Основной)",
            "К_14 (Основной)",
            "Альфа 1.2 (Основной)",
            "К_13 (Основной)",
            "Бета 3.3+3.4 (Основной)",
            "Альфа 5.5 (Основной)",
            "Альфа 5.13 (Основной)",
            "К_20 (Основной)",
            "Альфа 5.10 (Основной)",
            "К_19 (Основной)",
            "1.08 К_Росатом (СПД) (Основной)",
            "К_12 (Основной)",
            "Бета 2.3 (Основной)",
            "К_18 (Основной)",
            "К_0 (Лингафонный кабинет) (Основной)",
            "Бета 3.1+3.2 (Основной)",
            "Альфа 4.5 (Основной)",
            "Альфа 1.1 (Основной)",
            "Альфа 4.6 (Основной)"
        ]


    '''
    This function gives you this week schedule for certain group.
    String with valid group name. (Group names must be written with '-' instead of ' ')
    Also you can choose between this week or next week.
    '''
    async def group(self, group, next=False):
        # Choosing method to use.
        # If we need second week of different from previous group, then we need to change page to new group.
        if type(group) != str or type(next) != type(False):
            raise TypeError('Group number must be a string. Type of variable next must be Bull.')

        session = aiohttp.ClientSession()
        session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 YaBrowser/25.8.0.0 Safari/537.36'
        })
        method = 'set'
        group = group.replace(' ', '-')
        if next:
            method = 'addWeek'

        try:
            async with session.get(self.URL_LOGIN_GROUP) as resp:
                text = await resp.text()
        except Exception as e:
            await session.close()
            raise NetworkError("Failed to make request to sirius university.")

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
            raise ParsingError('No token found')

        # Setting data
        payload = {
            "updates": [
                {
                    "type": "callMethod",
                    "payload": {
                        "id": "get1",
                        "method": 'set',
                        "params": [group]
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
            if next:
                async with session.post(self.URL_GROUP, headers=headers, json=payload) as r:
                    a = await r.json()
                payload['serverMemo'] = a['serverMemo']
                payload['updates'][0]['payload']['method'] = method

            async with session.post(self.URL_GROUP, headers=headers, json=payload) as response:
                print('requested')
                if next:
                    print(await response.text())
                ans = await response.json()
        except Exception as e:
            await session.close()
            raise NetworkError("Failed to make request to sirius university.")

        # Creates the returning dictionary
        schedule = {
            'monday': [],
            'tuesday': [],
            'wednesday': [],
            'thursday': [],
            'friday': [],
            'saturday': [],
            'sunday': [],
        }
        try:
            if not ans['serverMemo']['data'].get('events', 0):
                print(ans['serverMemo'])
                await session.close()
                return schedule
            for i in ans['serverMemo']['data']['events'].keys():
                for j in ans['serverMemo']['data']['events'][i]:
                    j['teacher'] = j['teachers'][list(j['teachers'].keys())[0]]
                    if type(j['teacher']) != str:
                        del j['teacher']['id']
                    del j['teachers']
                    del j['code']
                    del j['color']
                    j['numberPair'] = i[:1]
                    match i[2:3]:
                        case '0':
                            schedule['monday'].append(j)
                        case '1':
                            schedule['tuesday'].append(j)
                        case '2':
                            schedule['wednesday'].append(j)
                        case '3':
                            schedule['thursday'].append(j)
                        case '4':
                            schedule['friday'].append(j)
                        case '5':
                            schedule['saturday'].append(j)
                        case '6':
                            schedule['sunday'].append(j)
        except Exception as e:
            print(e)
            await session.close()
            raise ScheduleParsingError("Error in parsing server response. Might be wrong group name.")
        for i in schedule:
            schedule[i].sort(key=lambda x: x['numberPair'])
        await session.close()
        return schedule

    '''
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
            async with session.get(self.URL_LOGIN_CLASSROOM) as resp:
                text = await resp.text()
        except Exception as e:
            await session.close()
            raise NetworkError('')

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
            async with session.post(self.URL_CLASSROOM, headers=headers, json=payload) as response:
                ans = await response.json()
            # Resetting position on web-site
            payload['updates'][0]['payload']['method'] = 'minusWeek'
            async with session.post(self.URL_CLASSROOM, headers=headers, json=payload) as r:
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
                        for m, time in enumerate(self.lessons):
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


    '''
    This function gives you free classrooms for certain time of today.
    '''
    async def get_free_classrooms(self, date=datetime.datetime.now()):
        # Collecting schedules
        all_classrooms = await asyncio.gather(*(self.classroom(classroom) for classroom in self.classrooms[:20]))
        all_classrooms_2 = await asyncio.gather(*(self.classroom(classroom) for classroom in self.classrooms[20:40]))
        all_classrooms_3 = await asyncio.gather(*(self.classroom(classroom) for classroom in self.classrooms[40:]))

        all_classrooms = all_classrooms + all_classrooms_2 + all_classrooms_3
        free_classrooms = []
        pair = 0

        # Defining which pair is it now.
        for i, time in enumerate(self.lessons):
            if time > date.hour * 60 + date.minute:
                pair = i
                break

        # Finding free classrooms
        for i in all_classrooms:
            if type(i) == str:
                free_classrooms.append(i)
                continue
            for j in i[date.weekday()]:
                if j['numberPair'] == pair:
                    break
                elif j['numberPair'] > pair:
                    free_classrooms.append(i['classroom'])
                    break
            else:
                free_classrooms.append(i['classroom'])
        return sorted(free_classrooms)