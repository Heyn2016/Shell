## Linux Shell for ARM(imx6)


#### [1] ME909s821_ECM
  
$  
  
#### [2] pbox_daemon
  
$vim pboxScript.service  
  
[Unit]  
Description=Pbox Daemon Shell  
After=multi-user.target `network-lte.service`  
  
[Service]  
Type=`simple`  
ExecStart=/home/pbox_daemon.sh  
[Install]  
WantedBy=multi-user.target  
  
$systemctl enable pboxScript.service  
$vim cora.timer  
  
[Unit]  
Description=Runs Pbox Script every 2 min  
  
[Timer]  
OnBootSec=1min  
OnUnitActiveSec=`2min`  
Unit=`pboxScript.service`  
  
[Install]  
WantedBy=multi-user.target  
  
$systemctl enable cora.timer  
$systemctl start cora.timer  
