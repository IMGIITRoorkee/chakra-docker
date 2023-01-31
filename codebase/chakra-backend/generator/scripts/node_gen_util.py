import os

from pathlib import Path

from chakra_backend.settings import PERSONAL_ROOT
from filemanager.models import Folder
from generator.utils.validnodes_config import WEBSITE_NODE_STRUCTURE
from generator.constants import JOSH_USER_FOLDER, HTML_FOLDER, XML_FOLDER, HINDI_FOLDER

josh_folder, _ = Folder.objects.get_or_create(
    folder_name=JOSH_USER_FOLDER, parent=None)

html_folder, _ = Folder.objects.get_or_create(
    folder_name=HTML_FOLDER, parent=None)
xml_folder, _ = Folder.objects.get_or_create(
    folder_name=XML_FOLDER, parent=None)
hindi_folder_xml, _ = Folder.objects.get_or_create(
    folder_name=HINDI_FOLDER,
    parent=xml_folder
)
hindi_folder_html, _ = Folder.objects.get_or_create(
    folder_name=HINDI_FOLDER,
    parent=html_folder
)


def create_nodes(node_dict: dict(), parent: Folder):

    for key in node_dict.keys():

        node, _ = Folder.objects.get_or_create(folder_name=key, parent=parent)
        path = os.path.join(PERSONAL_ROOT, node.relative_path)
        assets_path = os.path.join(path, "assets")
        os.makedirs(Path(assets_path))
        create_nodes(node_dict[key], node)


create_nodes(WEBSITE_NODE_STRUCTURE, html_folder)
create_nodes(WEBSITE_NODE_STRUCTURE, xml_folder)
# comment above two and import this module in shell (python manage.py shell)
create_nodes(WEBSITE_NODE_STRUCTURE, hindi_folder_xml)
create_nodes(WEBSITE_NODE_STRUCTURE, hindi_folder_html)
