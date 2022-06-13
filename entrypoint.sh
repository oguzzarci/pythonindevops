#!/bin/sh
gunicorn app:application -w 4 --threads 2 -b 0.0.0.0:3000