import awsgi
from flask import (
    Flask,
    jsonify,
)

app = Flask(__name__)

@app.route('/')
def index():
    return jsonify(status=200, message='OK')

@app.route('/installs/')
def installs():
    result = {'installs': '0'}
    return jsonify(result)        

@app.route('/packages/')
def packages():
    result = {'packages': '0'}
    return jsonify(result)        

if __name__ == '__main__':
     app.run(port='5002')

def lambda_handler(event, context):
    return awsgi.response(app, event, context, base64_content_types={"text/json"})