import logging

def set_logger():

    # 1. Создаем "Личность" логгера.
    # Обязательно даем имя (обычно __name__ - имя текущего файла).

    logger = logging.getLogger('logs')
    logger.setLevel(logging.DEBUG)

    # Создаем каналы передачи - Handlers

    # Файл (Архив)
    file_handler = logging.FileHandler("app_detailed.log", encoding='utf-8')
    file_handler.setLevel(logging.DEBUG) # В файл пишем даже мелочи

    # Консоль (Экран)
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.WARNING) # На экран выводим только важное, чтобы не мусорить

    # Форматирование
    detailed_format = logging.Formatter("%(asctime)s - %(levelname)s - %(name)s - %(message)s")
    simple_format = logging.Formatter("%(levelname)s: %(message)s")

    file_handler.setFormatter(detailed_format)
    console_handler.setFormatter(simple_format)

    # Подключаем
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    return logger

# logger.debug("Переменная x = 5")     # Запишется ТОЛЬКО в файл
# logger.error("Сервер упал!")         # Появится И в файле, И в консоли