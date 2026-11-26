# Отчёт по курсовой работе

`report.typ` - исходник, `report.pdf` - собранный отчёт. Команды ниже выполняются из корня `kp` в WSL; подходят для fish.

Сборка PDF по сохранённым таблицам и иллюстрациям:

```sh
typst compile --font-path /mnt/c/Windows/Fonts report/report.typ report/report.pdf
```

Для повторного получения измерений и иллюстраций:

```sh
make
uv venv build/report-venv
uv pip install --python build/report-venv/bin/python matplotlib pillow
build/report-venv/bin/python report/measure.py
build/report-venv/bin/python report/figures.py
typst compile --font-path /mnt/c/Windows/Fonts report/report.typ report/report.pdf
```

Измерения требуют доступного NVIDIA GPU и текущей текстуры из конфигурации `--default`. Скрипт перезаписывает результаты отчёта; кадры сохраняет в игнорируемом каталоге `build/report-runs`.

`benchmark_results.csv` содержит среднее кадров 1-3 после прогрева на кадре 0. В `measurements` находятся входные конфигурации и исходные строки статистики. `environment.json` фиксирует среду и контрольные суммы программы. `scene.txt` - использованная конфигурация сцены.
