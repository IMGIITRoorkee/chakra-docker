select 'generator_page', count(*) from generator_page
union all select 'generator_xmlpage', count(*) from generator_xmlpage
union all select 'chakra_auth_chakrauser', count(*) from chakra_auth_chakrauser
union all select 'filemanager_file', count(*) from filemanager_file
union all select 'filemanager_folder', count(*) from filemanager_folder
union all select 'generator_editlog', count(*) from generator_editlog
union all select 'generator_header', count(*) from generator_header
union all select 'generator_menu', count(*) from generator_menu
union all select 'confman_shorturl', count(*) from confman_shorturl
union all select 'confman_subdomain', count(*) from confman_subdomain
union all select 'django_migrations', count(*) from django_migrations
union all select 'max_editlog_id', max(id) from generator_editlog;
