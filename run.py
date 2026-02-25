import uvicorn
import os
import socket

def get_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # doesn't even have to be reachable
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

if __name__ == "__main__":
    local_ip = get_ip()
    print(f"--- SIBIT RUNNER ---")
    print(f"Akses dari laptop ini: http://localhost:8000")
    print(f"Akses dari HP (Scan QR): http://{local_ip}:8000")
    print(f"--------------------")
    
    # Jalankan server
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)
