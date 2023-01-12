Pour rappel, le projet consiste à mettre en place un wordpress haute disponibilité. Ce wordpress est mis en place lui même grâce à l'implémentation de scripts Terraform et Ansible.


Terraform est utilisé pour le déploiement d'instances cloud. Dans ce projet, la partie Terraform est composée de :

- un fichier providers.tf
- un fichier variables.tf
- un fichier de script main.tf
- un dossier template qui contient :
    - un template générique de l'inventaire automatique


Ansible est utilisé pour déployer les configurations sur ces mêmes instances. Dans ce projet, la partie Ansible est composée de :

- un fichier playbooks.yml
- un dossier template contenant:
    - un fichier default.j2
    - un fichier haproxy.cfg.j2
    - un fichier index.html.j2
    - un dossier ifconfig.io qui est le dossier docker de l'application web ifconfig.io

Le dossier Terraform

Il est composé de trois fichiers et d'un dossier templates.

Le fichier providers.tf qui contient la version requise et les providers requis.
Le fichier variables.tf sert à contenir les différentes variables utilisées.
Le fichier main.tf est composé d'une partie vRack et d'une partie instances et clés SSH.

Le dossier Ansible

Il est composé de deux types de fichiers : les templates et le playbook.

Le dossier template qui regroupe les différents templates.
Le dossier ifconfig.io qui aide à récupérer l'adresse ip.
Le fichier default.j2 est destiné au serveur web nginx.
Le fichier docker-compose.yml.j2 est le fichier template docker-compose du Wordpress.
Le fichier exports.j2 sert à configurer le serveur NFS.
Le fichier haproxy.cfg.j2 est le fichier de configuration principal du reverse proxy haproxy.
Le fichier index.html.j2 est le fichier template de la page web.
Le fichier playbook.yml est le fichier de configuration des instances.
