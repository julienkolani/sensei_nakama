"""
Application: AutoAdmin Service Manager
Description: Cette application gère automatiquement le redémarrage des services, l'exécution de commandes personnalisées, et la gestion de services Docker Compose. Elle envoie également des rapports d'état à une instance Rocket.Chat toutes les 4 heures.
Auteur: [Votre Nom]
Date: [Date]
Version: 1.0

Paquets nécessaires:
- configparser
- logging
- rocketchat_API
- threading
- os
- time
"""

import os
import time
import threading
from configparser import ConfigParser
import logging
from rocketchat.api import RocketChatAPI

# Nom du fichier de configuration
CONFIG_FILE = '/etc/sensei_nakama/sensei_nakama.conf'

# Configuration par défaut de l'application
app_config = {
    'notify_bot_username': None,
    'notify_bot_password': None,
    'notify_user_list': None,
    'notify_domain': None,
    'retry_interval_seconds': 60,
    'log_file_path': './autoadmin.log'
}

# Fonction de chargement de la configuration à partir du fichier
def load_config():
    config = []
    current_section = {}
    section_name = None

    with open(CONFIG_FILE, 'r') as f:
        lines = f.readlines()

        for line in lines:
            line = line.strip()
            # Ignorer les commentaires et les lignes vides
            if line.startswith('#') or not line:
                continue
            # Début d'une nouvelle section
            if line.startswith('[') and line.endswith(']'):
                if section_name:
                    config.append((section_name, current_section))
                section_name = line[1:-1]
                current_section = {}
            # Clé-Valeur dans la section actuelle
            elif '=' in line:
                key, value = line.split('=', 1)
                current_section[key.strip()] = value.strip()
        # Ajouter la dernière section
        if section_name:
            config.append((section_name, current_section))

    return config

# Fonction d'affichage de la configuration chargée
def display_config(config):
    for section, options in config:
        print(f"[{section}]")
        for key, value in options.items():
            print(f"{key} = {value}")
        print()

# Initialisation de la journalisation
def init_logging():
    log_file_path = app_config.get('log_file_path', './autoadmin.log')
    logging.basicConfig(filename=log_file_path, level=logging.INFO,
                        format='%(asctime)s:%(levelname)s:%(message)s')

# Gestion du redémarrage des services
def handle_service(section, options):
    required_fields = ['name', 'interval']
    for field in required_fields:
        if field not in options:
            logging.error(f"Missing required field '{field}' in section [{section}]")
            return

    service_name = options['name']
    interval = int(options.get('interval', app_config['retry_interval_seconds']))

    while True:
        try:
            logging.info(f"Restarting service {service_name}")
            os.system(f"systemctl restart {service_name}")
            time.sleep(interval)
        except Exception as e:
            logging.error(f"Error handling service {service_name}: {e}")
            time.sleep(app_config['retry_interval_seconds'])

# Gestion de l'exécution des commandes personnalisées
def handle_custom_config(section, options):
    required_fields = ['exec']
    for field in required_fields:
        if field not in options:
            logging.error(f"Missing required field '{field}' in section [{section}]")
            return

    command = options['exec']
    interval = int(options.get('interval', app_config['retry_interval_seconds']))

    while True:
        try:
            logging.info(f"Executing command: {command}")
            os.system(command)
            time.sleep(interval)
        except Exception as e:
            logging.error(f"Error executing command {command}: {e}")
            time.sleep(app_config['retry_interval_seconds'])

# Gestion des services Docker Compose
def handle_compose_service(section, options):
    required_fields = ['name', 'path']
    for field in required_fields:
        if field not in options:
            logging.error(f"Missing required field '{field}' in section [{section}]")
            return

    service_name = options['name']
    compose_path = options['path']

    while True:
        try:
            logging.info(f"Starting Docker Compose service {service_name}")
            os.system(f"docker-compose -f {compose_path} up -d")
            time.sleep(app_config['retry_interval_seconds'])
        except Exception as e:
            logging.error(f"Error handling Docker Compose service {service_name}: {e}")
            time.sleep(app_config['retry_interval_seconds'])

# Gestion de la configuration de l'application
def handle_app_config(section, options):
    global app_config
    if 'notify_bot_username' in options:
        app_config['notify_bot_username'] = options['notify_bot_username']
    if 'notify_bot_password' in options:
        app_config['notify_bot_password'] = options['notify_bot_password']
    if 'notify_user_list' in options:
        app_config['notify_user_list'] = options['notify_user_list']
    if 'notify_domain' in options:
        app_config['notify_domain'] = options['notify_domain']
    if 'retry_interval_seconds' in options:
        app_config['retry_interval_seconds'] = int(options['retry_interval_seconds'])
    if 'log_file_path' in options:
        app_config['log_file_path'] = options['log_file_path']

# Envoi de rapport à Rocket.Chat
def send_report(api, restarted_services, actions_performed, actions_results):
    message = sensei_nakama_report(restarted_services, actions_performed, actions_results)
    user_list = app_config['notify_user_list'].split(',')
    for user_id in user_list:
        api.send_message(message, user_id.strip())

# Création du message de rapport
def sensei_nakama_report(restarted_services, actions_performed, actions_results):
    message = f":robot_face: **SenseiNakama Reporting, Captain!** :ship:\n\n"
    message += "**Restarted Services:** ⤵**\n"
    message += "| Service |\n"
    message += "| --- |\n"
    for service in restarted_services:
        system_service = service.capitalize() if service.islower() else service
        message += f"| {system_service} |\n"
    message += "\n**Actions Performed and Results:** ⤵**\n"
    message += "| Action | Result |\n"
    message += "| --- | --- |\n"
    for action, result in zip(actions_performed, actions_results):
        message += f"| :wrench: {action} | :heavy_check_mark: {result} |\n"
    message += "\n:sparkles: **That's all for now, Captain!** :sparkles:\n"
    message += "Remember, '*I'm going to be the King of the Pirates!*' - Luffy :crown:\n"
    return message

# Fonction du thread pour l'envoi de rapports toutes les 4 heures
def report_thread(api, restarted_services, actions_performed, actions_results):
    while True:
        try:
            send_report(api, restarted_services, actions_performed, actions_results)
            logging.info("Report sent successfully")
            time.sleep(14400)  # 4 heures en secondes
        except Exception as e:
            logging.error(f"Error sending report: {e}")
            time.sleep(app_config['retry_interval_seconds'])

# Fonction principale
def main():
    # Initialisation de la journalisation
    init_logging()

    # Chargement de la configuration
    config = load_config()
    display_config(config)

    restarted_services = []
    actions_performed = []
    actions_results = []

    # Initialisation de l'API Rocket.Chat
    api = RocketChatAPI(settings={
        'username': app_config['notify_bot_username'],
        'password': app_config['notify_bot_password'],
        'domain': app_config['notify_domain']
    })

    # Démarrage du thread de rapport
    report_thread_instance = threading.Thread(target=report_thread, args=(api, restarted_services, actions_performed, actions_results))
    report_thread_instance.start()

    # Traitement des sections de la configuration
    for section, options in config:
        if section.startswith('service'):
            thread = threading.Thread(target=handle_service, args=(section, options))
            thread.start()
            restarted_services.append(options['name'])
        elif section.startswith('custom_config'):
            thread = threading.Thread(target=handle_custom_config, args=(section, options))
            thread.start()
            actions_performed.append(options['exec'])
            actions_results.append("Executed successfully")
        elif section.startswith('composeservice'):
            thread = threading.Thread(target=handle_compose_service, args=(section, options))
            thread.start()
            restarted_services.append(options['name'])
        elif section == 'appconfig':
            handle_app_config(section, options)

if __name__ == '__main__':
    main()
