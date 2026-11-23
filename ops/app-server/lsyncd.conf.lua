-- Pushes published content and ConfMan nginx configs to root2 and to its AWS replica, through reverse tunnels.
-- delete = true removes files on both targets; the replica applies nginx-incoming/ itself after nginx -t.
local B = "/home/ubuntu/chakra-docker/codebase/chakra-backend"
local RSYNC = {
    rsh = "/usr/bin/ssh -F /etc/lsyncd/ssh_config",
    links = true, times = true, perms = true, protect_args = true,
}

settings {
    logfile = "/var/log/lsyncd/lsyncd.log",
    statusFile = "/var/log/lsyncd/lsyncd.status",
    insist = true,
}

local function stream(host, src, dst, extra)
    local s = { default.rsync, source = B .. src, target = host .. ":" .. dst, delete = true, delay = 3, rsync = RSYNC }
    for k, v in pairs(extra or {}) do s[k] = v end
    sync(s)
end

local NGINX = {
    root2 = "/etc/nginx/",
    replica = "/home/root2/nginx-incoming/",
}

for host, nginx in pairs(NGINX) do
    stream(host, "/website/HTML/", "/home/root2/new_website/", { exclude = { "/Josh Users/" } })
    stream(host, "/website/JoshUsers/", "/home/root2/new_website/Josh Users/")
    stream(host, "/reverse_proxy_configurations/subdomains/", nginx .. "sites-available/subdomains/")
    stream(host, "/reverse_proxy_configurations/shorturls/", nginx .. "conf.d/includes/")
    stream(host, "/reverse_proxy_configurations/josh-subdomains/", nginx .. "sites-available/josh-subdomains/")
end
