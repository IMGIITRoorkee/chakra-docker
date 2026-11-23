import os
from chakra_backend.settings import HTML_ROOT_URL
from filemanager.models import Folder
made = total = 0
for f in Folder.objects.all().iterator():
    path = f.path
    if not path.startswith(HTML_ROOT_URL):
        continue
    total += 1
    if not os.path.isdir(path):
        os.makedirs(path, exist_ok=True)
        made += 1
print('html folders', total, 'created', made)
