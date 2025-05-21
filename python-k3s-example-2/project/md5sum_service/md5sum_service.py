from flask import Flask, request, jsonify
import hashlib

app = Flask(__name__)

@app.route('/md5', methods=['POST'])
def compute_md5():
    # Read raw binary data from request body
    file_bytes = request.get_data()
    # Compute MD5 checksum
    md5sum = hashlib.md5(file_bytes).hexdigest()
    return jsonify({"md5sum": md5sum})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)

