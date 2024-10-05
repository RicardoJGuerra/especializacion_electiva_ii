#!/bin/bash
# Actualizamos el sistema actual e instalamos los requisitos
sudo yum update -y

# Instalamos Docker en la instancia
sudo yum install docker -y

# Iniciamos Docker dentro de la instancia
sudo systemctl start docker 

# Agregamos el usuario ec2-user al grupo docker para ejecutar sin sudo
sudo usermod -a -G docker ec2-user

# Habilitamos Docker para iniciar con el sistema
sudo systemctl enable docker

# Descargamos e iniciamos el contenedor de Nginx
sudo docker run -d -p 80:80 --name nginx-container nginx