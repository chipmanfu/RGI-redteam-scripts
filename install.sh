#!/bin/bash
cd RGI-redteam-scripts
mv backbonerouters /root/
mv scripts /root/
chmod 755 /root/scripts/*.sh
chmod 755 /root/scripts/phish/*.sh
mv /root/backbonerouters/hosts /etc/hosts
cd ..
rm -r RGI-redteam-scripts
