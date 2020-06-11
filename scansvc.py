#!/usr/bin/env python
from mfrc522 import SimpleMFRC522
import time
import subprocess
import os
import glob
from pathlib import Path
import shutil

reader = SimpleMFRC522()
directory = '/media/tmp/'
current_id = '0'

try:
       r = glob.glob('/media/tmp/*')
       for i in r:
               os.remove(i)
except OSError:
       pass

while True:
        id, data = reader.read()
        if current_id != id:
                try:
                        r = glob.glob('/media/tmp/*')
                        for i in r:
                                os.remove(i)
                except OSError:
                        pass
                start_time = time.time()
                text_file = open(directory + str(id), "w")
                text_file.write(str(start_time))
                text_file.close()
                current_id = id

        else:
                Path(directory + str(id)).touch()
                time.sleep(2)
