#!bin/sh

echo "#Startlogging"
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>scriptlog.out 2>&1

echo "#Install Nginx"
sudo apt-get update 
sudo apt install nginx -y
systemctl status nginx

echo "#Install Nodejs, Yarn, PM2 & Dependencies"
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash - 

sudo apt install -y nodejs
sudo apt install npm -y
sudo apt install yarn -y
sudo npm install -g pm2 -y

echo "#Install App & Start w/ NPM | PM2"
cd /opt/ 
sudo mkdir app
cd app
sudo git clone https://github.com/Kendubu1/covid-19-demo-express-js-app.git .
sudo npm install 
#(npm start&)
#pm2 start src/index.js 

echo "# Configure Nginx" 
export PUBLIC_IP=$(curl -s http://checkip.amazonaws.com || printf "0.0.0.0")
sudo sed -i "s/worker_processes.*;/worker_processes 1;/" /etc/nginx/nginx.conf
sudo sed -i "s/worker_connections.*;/worker_connections 3;/" /etc/nginx/nginx.conf
sudo sh -c "printf '%s\n' '' \
    'server {' \
    '    listen 80;' \
    '    listen [::]:80;' \
    '    server_name "$PUBLIC_IP";' \
    'location / {' \
    '    proxy_pass http://localhost:3000/;' \
    '     }' \
    '     }' \
    '' > /etc/nginx/conf.d/node.conf"
sudo nginx -s reload

echo "#Configure & Start Node Service"
#sudo printf '%s\n' '#!bin/bash' 'pm2 start /opt/app/src/index.js' > /opt/app/node.sh
sudo printf '%s\n' '#!bin/bash' 'cd /opt/app' 'npm start' > /opt/app/node.sh
sudo chmod +x /opt/app/node.sh
sudo printf '%s\n' '' \
    '[Unit]' \
    'Description=node start script' \
    ''\
    '[Service]' \
    'ExecStart=/opt/app/node.sh' \
    'StandardOutput=syslog'\
    'StandardError=syslog'\
    ''\
    '[Install]' \
    'WantedBy=multi-user.target' \
    '' > /etc/systemd/nodeapp.service

cp /etc/systemd/nodeapp.service /lib/systemd/system
sudo systemctl enable nodeapp.service
sudo systemctl start nodeapp

