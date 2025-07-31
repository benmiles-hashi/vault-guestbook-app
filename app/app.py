import os
import hvac
import mysql.connector
from flask import Flask, request, redirect, url_for
from cryptography import x509
from cryptography.hazmat.backends import default_backend

# ─── Config ───────────────────────────────────────────────────────────────────
VAULT_ADDR    = os.environ['VAULT_ADDR']
VAULT_TOKEN   = os.environ['VAULT_TOKEN']
VAULT_DB_ROLE = os.environ['VAULT_DB_ROLE']
DB_NAME       = os.environ['DB_NAME']
CERT_CN       = os.environ.get('CERT_CN', 'localhost')
CERT_TTL      = os.environ.get('CERT_TTL', '24h')
CERT_DIR      = '/app/certs'

# ─── Vault client ─────────────────────────────────────────────────────────────
vault = hvac.Client(url=VAULT_ADDR, token=VAULT_TOKEN)

# ─── Flask app ────────────────────────────────────────────────────────────────
app = Flask(__name__)

def fetch_tls_cert():
    """
    Issue a new TLS cert via Vault PKI and write it to disk.
    """
    resp = vault.write(
        'pki/issue/webserver',
        common_name=CERT_CN,
        ttl=CERT_TTL
    )
    data = resp['data']
    os.makedirs(CERT_DIR, exist_ok=True)
    with open(f'{CERT_DIR}/chain.pem','w') as f:
        f.write(data['certificate'])
    with open(f'{CERT_DIR}/tls.key','w') as f:
        f.write(data['private_key'])

@app.route('/', methods=['GET','POST'])
def index():
    # 1) Generate fresh DB credentials + get lease_id
    secret = vault.secrets.database.generate_credentials(name=VAULT_DB_ROLE)
    db_user  = secret['data']['username']
    db_pass  = secret['data']['password']
    lease_id = secret['lease_id']

    # 2) Connect to MySQL
    conn = mysql.connector.connect(
        host='mysql',
        database=DB_NAME,
        user=db_user,
        password=db_pass
    )
    cur = conn.cursor()

    # 3) If POST, insert the form data
    if request.method == 'POST':
        name    = request.form.get('name','').strip()
        message = request.form.get('message','').strip()
        if name and message:
            cur.execute(
                "INSERT INTO guestbook (name,message) VALUES (%s,%s)",
                (name, message)
            )
            conn.commit()
        return redirect(url_for('index'))

    # 4) Fetch all entries
    cur.execute("SELECT name,message,created_at FROM guestbook ORDER BY id DESC")
    entries = cur.fetchall()
    cur.close()
    conn.close()

    # 5) Load & parse current TLS cert
    with open(f'{CERT_DIR}/chain.pem','rb') as f:
        pem = f.read()
    cert = x509.load_pem_x509_certificate(pem, default_backend())
    serial  = format(cert.serial_number,'x').upper()
    expires = cert.not_valid_after.isoformat()

    # 6) Render HTML
    rows = "\n".join(
        f"<li><strong>{e[0]}</strong> <em>({e[2]})</em>: {e[1]}</li>"
        for e in entries
    )
    return f"""
    <html>
      <head>
        <title>Vault Guestbook Demo</title>
        <style>
          body {{ font-family:sans-serif; padding:2rem; }}
          .box {{ border:1px solid #ccc; padding:1rem; margin-bottom:1rem; }}
          form {{ margin-bottom:2rem; }}
          label {{ display:block; margin-top:.5rem; }}
          input, textarea {{ width:100%; padding:.5rem; }}
          button {{ margin-top:.5rem; padding:.5rem 1rem; }}
        </style>
      </head>
      <body>
        <h1>✍️  Vault Guestbook</h1>

        <form method="post">
          <label>Name:
            <input name="name" required>
          </label>
          <label>Message:
            <textarea name="message" rows="3" required></textarea>
          </label>
          <button type="submit">Sign Guestbook</button>
        </form>

        <div class="box">
          <strong>🔑 Vault DB lease/user:</strong><br>
          <code>{lease_id}</code>
        </div>
        <div class="box">
          <strong>🔒 Cert serial number:</strong><br>
          <code>{serial}</code>
        </div>
        <div class="box">
          <strong>⏰ Cert expiration:</strong><br>
          <code>{expires}</code>
        </div>

        <h2>Guestbook Entries</h2>
        <div class="box" style="max-height:300px; overflow:auto;">
          <ul>
            {rows}
          </ul>
        </div>
      </body>
    </html>
    """

if __name__ == '__main__':
    # Fetch a new cert on container start
    fetch_tls_cert()
    ssl_ctx = (f'{CERT_DIR}/chain.pem', f'{CERT_DIR}/tls.key')
    print(f"[+] HTTPS up (cert TTL={CERT_TTL}, CN={CERT_CN})")
    app.run(host='0.0.0.0', port=5000, ssl_context=ssl_ctx)
