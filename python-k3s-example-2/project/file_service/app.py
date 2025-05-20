from flask import Flask, request, jsonify, send_from_directory
import base64
import os
import requests
from database import init_db, log_file_metadata, query_file_metadata
from werkzeug.utils import secure_filename

UPLOAD_FOLDER = '/data/uploads'
DB_PATH = '/data/metadata.db'

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Ensure upload folder exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Initialize the database
init_db(DB_PATH)

def get_md5_from_service(file_path):
    with open(file_path, "rb") as f:
        file_bytes = f.read()
    # Send file bytes directly with appropriate headers
    headers = {"Content-Type": "application/octet-stream"}
    response = requests.post('http://md5sum-service/md5', data=file_bytes, headers=headers)
    response.raise_for_status()
    return response.json()["md5sum"]

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return "No file part", 400
    file = request.files['file']
    if file.filename == '':
        return "No selected file", 400
    
    filename = secure_filename(file.filename)
    file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(file_path)
    file_size = os.path.getsize(file_path)
    file_md5 = get_md5_from_service(file_path)
    
    # Log metadata to database
    log_file_metadata(DB_PATH, filename, file_path, file_size, file_md5)
    
    return jsonify({
        "filename": filename,
        "path": file_path,
        "size": file_size,
        "md5sum": file_md5
    })

@app.route('/files', methods=['GET'])
def list_files():
    files = query_file_metadata(DB_PATH)
    return jsonify(files)

@app.route('/download/<path:filename>', methods=['GET'])
def download_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename, as_attachment=True)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
