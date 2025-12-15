import json
import csv
import os
import copy

# =============================================================
# --- PARAMETER CONFIGURATION (Modify your settings here) ---
# =============================================================

# General Settings
CONFIG_FILE_PREFIX = "config"
TEMPLATE_FILE = "spec_gb200_nvl_72_2_4_compute_nodes_nvlgpustress_partner_mfg.json"          
INPUT_CSV_FILE = "rack_config.csv"      
OUTPUT_DIR = "rack_spec" 

# !!! CRITICAL PATH A: Path to the 'hosts' dictionary !!!
HOSTS_PATH = ["global_args", "cluster_cfg", "hosts"] 

# !!! CRITICAL PATH B: Path to the 'cluster_node_logins' dictionary !!!
LOGIN_PATH = ["global_args", "cluster_cfg", "cluster_node_logins"]

# Node IP Logic Configuration (Used for calculating new IPs based on CSV)
NODE_IP_LOGIC = {
    "compute_node": {
        "ip_step": 1,
        "ip_prefix_key": "compute_ip_prefix", 
        "start_key": "compute_start"          
    },
    "switch_node": {
        "ip_step": 2,                         
        "ip_prefix_key": "switch_ip_prefix",  
        "start_key": "switch_start"           
    },
    # 'inter_switch_node' is handled only for login credentials, not IP replacement
}

# Login Credentials (MUST BE CHANGED!)
LOGIN_CREDENTIALS = {
    "compute_node": {"user": "pdmfg", "passwd": "pdmfg"},
    "switch_node": {"user": "admin", "passwd": "Aivres@111"},
    "inter_switch_node": {"user": "root_inter_switch", "passwd": "password_inter_switch"},
}

# =============================================================
# --- HELPER FUNCTIONS ---
# =============================================================

def load_template(template_path):
    """Loads the JSON template file."""
    try:
        with open(template_path, 'r', encoding='utf-8') as f:
            template_data = json.load(f)
        print(f"[OK] Successfully loaded template: {template_path}")
        return template_data
    except FileNotFoundError:
        print(f"[ERROR] FATAL: Template file {template_path} not found. Exiting.")
        return None
    except json.JSONDecodeError as e:
        print(f"[ERROR] FATAL: Template file {template_path} is not valid JSON. Details: {e}")
        return None

def get_nested_key(data, path):
    """
    Navigates through nested dictionaries to find the parent of the target key.
    Returns the parent dictionary and the target key name.
    """
    current = data
    target_key_name = path[-1]
    
    for key in path[:-1]: 
        if key in current and isinstance(current[key], dict):
            current = current[key]
        else:
            return None, None 
    
    return current, target_key_name 

def update_login_credentials(data, path, credentials):
    """Navigates to the login path and updates user/passwd for all specified node types."""
    
    login_parent, login_key = get_nested_key(data, path)
    
    if login_parent is None or login_key not in login_parent or not isinstance(login_parent[login_key], dict):
        print(f"[WARN] Login path {' -> '.join(path)} not found or is invalid. Skipping credential update.")
        return False
        
    login_config = login_parent[login_key]
    update_count = 0
    
    for node_type, creds in credentials.items():
        if node_type in login_config:
            login_config[node_type]["user"] = creds["user"]
            login_config[node_type]["passwd"] = creds["passwd"]
            update_count += 1
            
    if update_count > 0:
        print(f"[INFO] Successfully updated {update_count} login configuration(s).")
        return True
    else:
        print("[WARN] No matching node types found in 'cluster_node_logins' for credential update.")
        return False

# =============================================================
# --- SCRIPT LOGIC ---
# =============================================================

def generate_json_configs_from_csv():
    """
    Main function to read CSV, load template, replace nested IPs, and update logins.
    """

    base_template = load_template(TEMPLATE_FILE)
    if base_template is None:
        return

    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"Created output directory: {OUTPUT_DIR}")
    
    # Initialize IP tracker for each node type
    ip_tracker = {node_type: {'current_octet': 0, 'prefix': ''} 
                  for node_type in NODE_IP_LOGIC}

    try:
        with open(INPUT_CSV_FILE, mode='r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            
            for row in reader:
                rack_id = row['rack_id'].strip()
                print(f"\n--- Generating configuration for rack {rack_id} ---")

                # 1. Initialize IP Tracker: Get starting IP info from CSV
                initialization_successful = True
                for node_type, config in NODE_IP_LOGIC.items():
                    try:
                        prefix = row[config['ip_prefix_key']].strip()
                        start_octet = int(row[config['start_key']])
                        ip_tracker[node_type]['current_octet'] = start_octet
                        ip_tracker[node_type]['prefix'] = prefix
                    except (KeyError, ValueError) as e:
                        print(f"[ERROR] CSV missing or invalid IP info for {node_type} (Error: {e}). Skipping rack.")
                        initialization_successful = False
                        break
                
                if not initialization_successful:
                    continue

                # 2. Get hosts block (Deep copy the template)
                rack_config_data = copy.deepcopy(base_template)
                target_parent, target_key = get_nested_key(rack_config_data, HOSTS_PATH)
                
                if target_parent is None or target_key not in target_parent or not isinstance(target_parent[target_key], dict):
                    print(f"[ERROR] Hosts path {' -> '.join(HOSTS_PATH)} is invalid or not a dictionary. Skipping rack.")
                    continue

                old_hosts_data = target_parent[target_key]
                new_hosts_data = {} 

                # 3. Iterate through hosts, replace IP based on node_type
                for old_ip, node_config in old_hosts_data.items():
                    node_type = node_config.get("node_type")
                    
                    if node_type in NODE_IP_LOGIC:
                        tracker = ip_tracker[node_type]
                        logic = NODE_IP_LOGIC[node_type]
                        
                        new_ip = f"{tracker['prefix']}{tracker['current_octet']}"
                        
                        # Create new node config (ensure no user/passwd)
                        new_node_config = {
                            k: v for k, v in node_config.items() 
                            if k not in ['user', 'passwd'] # Explicitly remove legacy auth fields
                        }
                        
                        new_hosts_data[new_ip] = new_node_config
                        
                        tracker['current_octet'] += logic['ip_step']
                        print(f"   -> IP Replaced: {old_ip} ({node_type}) -> {new_ip}")
                    else:
                        # Retain nodes with undefined types
                        new_hosts_data[old_ip] = node_config
                
                # 4. Overwrite the hosts dictionary in the template
                target_parent[target_key] = new_hosts_data
                print(f"[OK] Completed IP replacement for {len(new_hosts_data)} hosts.")

                # 5. Update central login credentials
                update_login_credentials(rack_config_data, LOGIN_PATH, LOGIN_CREDENTIALS)

                # 6. Write the output file
                output_filename = os.path.join(OUTPUT_DIR, f"{CONFIG_FILE_PREFIX}_{rack_id}.json")
                with open(output_filename, 'w', encoding='utf-8') as f:
                    json.dump(rack_config_data, f, indent=4, ensure_ascii=False)
                print(f"[OK] Successfully generated file: {output_filename}")

    except FileNotFoundError:
        print(f"[ERROR] FATAL: Input CSV file {INPUT_CSV_FILE} not found. Please ensure it exists.")
    except Exception as e:
        print(f"[ERROR] FATAL: An unexpected error occurred: {e}")

if __name__ == '__main__':
    generate_json_configs_from_csv()
