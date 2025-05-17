#!/bin/bash


admin_user=openvpn
admin_pw=Admin@1234
reroute_gw=1 #this tells the vpn or routing system t redirect all your internet traffic(defult gateway) through the vpn tunnel
reroute_dns=1 
#this config the system to use the vpn provider's DNS servers insted of your defult ones.(usecase: prevent DNS leaks which can expose your browsing activity even if your using a vpn)
#here 1 means enble/true 0 means disable/false