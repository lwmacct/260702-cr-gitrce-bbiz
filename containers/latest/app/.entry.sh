#!/bin/bash
# author https://github.com/lwmacct

__main() {
  mkdir -p /app/data/logs
  cat >/etc/supervisord.conf <<EOF
[unix_http_server]
file=/run/supervisord.sock
chmod=0700
chown=nobody:nogroup

[supervisord]
user=root
nodaemon=true
logfile=/var/log/supervisord.log
logfile_maxbytes=5MB
logfile_backups=2
pidfile=/var/run/supervisord.pid

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///run/supervisord.sock
prompt=mysupervisor
history_file=~/.sc_history

[include]
files = /etc/supervisor/conf.d/*.conf /app/data/.gitrce/supervisor.d/*.conf
EOF

  cat >/etc/supervisor/conf.d/cron.conf <<EOF
[program:cron]
command=cron -f
autostart=true
autorestart=true
startretries=3
user=root
environment=TERM="xterm"
redirect_stderr=true
stdout_logfile=/app/data/logs/cron.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
EOF

  cat >/etc/supervisor/conf.d/gitrce.conf <<EOF
[program:gitrce]
command=/app/.gitrce.sh
autostart=true
autorestart=true
startretries=3
user=root
environment=TERM="xterm"
redirect_stderr=true
stdout_logfile=/app/data/logs/gitrce.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
EOF

  exec supervisord

}

__main
