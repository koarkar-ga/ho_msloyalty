import paramiko

hostname = '188.166.250.198'
username = 'root'
password = 'D@nger0us99MOONSUN'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print(f"Connecting to {hostname}...")
    client.connect(hostname, username=username, password=password, timeout=10)
    print("Connected successfully!")
    
    commands = [
        "tail -n 60 /root/.pm2/logs/pos-api-error.log",
        "tail -n 60 /root/.pm2/logs/pos-api-out.log"
    ]
    
    for cmd in commands:
        print(f"\n--- Running: {cmd} ---")
        stdin, stdout, stderr = client.exec_command(cmd)
        print(stdout.read().decode().strip())
        print(stderr.read().decode().strip())
        
except Exception as e:
    print(f"Failed: {e}")
finally:
    client.close()
